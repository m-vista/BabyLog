import { readFile } from "node:fs/promises";
import { after, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";

const projectId = "demo-babylog";
const babyId = "baby-a";
const collections = [
  "pumpSessions",
  "bottleFeeds",
  "nursingSessions",
  "sleepSessions",
  "diaperEvents",
  "checklistItems",
  "checklistEvents",
  "growthMeasurements",
];

let environment;

function context(userID) {
  return environment.authenticatedContext(userID).firestore();
}

function babyData(createdByUserID = "owner") {
  const now = new Date("2026-01-01T00:00:00Z");
  return {
    id: babyId,
    name: "Test Baby",
    birthDate: now,
    createdByUserID,
    nightStartMinutes: 1140,
    nightEndMinutes: 420,
    createdAt: now,
    updatedAt: now,
  };
}

function memberData(userID, role, status = "active") {
  const now = new Date("2026-01-01T00:00:00Z");
  return {
    id: userID,
    babyID: babyId,
    userID,
    role,
    status,
    createdAt: now,
    updatedAt: now,
  };
}

function eventData(id, userID, overrides = {}) {
  const now = new Date("2026-01-01T00:00:00Z");
  return {
    id,
    babyID: babyId,
    createdByUserID: userID,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function pumpData(id, userID, overrides = {}) {
  return eventData(id, userID, {
    startTime: new Date("2026-01-02T10:00:00Z"),
    durationSeconds: 600,
    leftAmountMl: 29.5735295625,
    rightAmountMl: 59.147059125,
    totalAmountMl: 88.7205886875,
    isPostNursing: false,
    notes: "Test note",
    ...overrides,
  });
}

async function seed() {
  await environment.withSecurityRulesDisabled(async (admin) => {
    const db = admin.firestore();
    await setDoc(doc(db, "babies", babyId), babyData());
    await setDoc(doc(db, "babies", babyId, "members", "owner"), memberData("owner", "owner"));
    await setDoc(doc(db, "babies", babyId, "members", "admin"), memberData("admin", "admin"));
    await setDoc(doc(db, "babies", babyId, "members", "caregiver"), memberData("caregiver", "caregiver"));
    for (const name of collections) {
      await setDoc(doc(db, "babies", babyId, name, "seed"), eventData("seed", "owner"));
    }
  });
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile(new URL("../firestore.rules", import.meta.url), "utf8"),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await seed();
});

after(async () => {
  await environment.cleanup();
});

describe("Firestore security rules", () => {
  test("active members can read the baby and write every data collection", async () => {
    const db = context("caregiver");
    await assertSucceeds(getDoc(doc(db, "babies", babyId)));
    for (const name of collections) {
      const id = `caregiver-${name}`;
      await assertSucceeds(setDoc(doc(db, "babies", babyId, name, id), eventData(id, "caregiver")));
    }
  });

  test("current user can run the membership collection-group lookup", async () => {
    const db = context("caregiver");
    const memberships = query(collectionGroup(db, "members"), where("userID", "==", "caregiver"));
    const snapshot = await assertSucceeds(getDocs(memberships));
    assert.equal(snapshot.size, 1);
  });

  test("unrelated user is denied on every baby collection", async () => {
    const db = context("unrelated");
    await assertFails(getDoc(doc(db, "babies", babyId)));
    await assertFails(getDoc(doc(db, "babies", babyId, "members", "owner")));
    for (const name of collections) {
      await assertFails(getDoc(doc(db, "babies", babyId, name, "seed")));
    }
  });

  test("unauthenticated user is denied", async () => {
    const db = environment.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "babies", babyId)));
    await assertFails(getDoc(doc(db, "users", "owner")));
  });

  test("users can access only their own profile", async () => {
    const db = context("owner");
    await assertSucceeds(setDoc(doc(db, "users", "owner"), { displayName: "Owner" }));
    await assertFails(setDoc(doc(db, "users", "other"), { displayName: "Other" }));
  });

  test("caregiver cannot update the baby or memberships", async () => {
    const db = context("caregiver");
    await assertFails(updateDoc(doc(db, "babies", babyId), { name: "Changed" }));
    await assertFails(updateDoc(doc(db, "babies", babyId, "members", "caregiver"), { status: "removed" }));
  });

  test("admin cannot modify or remove owner or grant owner", async () => {
    const db = context("admin");
    await assertFails(updateDoc(doc(db, "babies", babyId, "members", "owner"), { status: "removed" }));
    await assertFails(updateDoc(doc(db, "babies", babyId, "members", "caregiver"), { role: "owner" }));
    await assertFails(setDoc(doc(db, "babies", babyId, "members", "new-owner"), memberData("new-owner", "owner")));
  });

  test("admin can manage caregiver memberships", async () => {
    const db = context("admin");
    await assertSucceeds(setDoc(doc(db, "babies", babyId, "members", "new-caregiver"), memberData("new-caregiver", "caregiver")));
    await assertSucceeds(updateDoc(doc(db, "babies", babyId, "members", "caregiver"), { status: "removed", updatedAt: new Date() }));
  });

  test("user cannot add themselves to someone else's baby", async () => {
    const db = context("unrelated");
    await assertFails(setDoc(doc(db, "babies", babyId, "members", "unrelated"), memberData("unrelated", "caregiver")));
  });

  test("mismatched babyID and createdByUserID are denied", async () => {
    const db = context("caregiver");
    await assertFails(setDoc(doc(db, "babies", babyId, "pumpSessions", "wrong-baby"), eventData("wrong-baby", "caregiver", { babyID: "other" })));
    await assertFails(setDoc(doc(db, "babies", babyId, "pumpSessions", "wrong-user"), eventData("wrong-user", "owner")));
  });

  test("createdByUserID is immutable", async () => {
    const db = context("caregiver");
    await assertFails(updateDoc(doc(db, "babies", babyId, "pumpSessions", "seed"), { createdByUserID: "caregiver" }));
  });

  test("pump sessions support idempotent CRUD and bounded range queries", async () => {
    const db = context("caregiver");
    const pumpID = "pump-round-trip";
    const pumpReference = doc(db, "babies", babyId, "pumpSessions", pumpID);
    const original = pumpData(pumpID, "caregiver");

    await assertSucceeds(setDoc(pumpReference, original));
    await assertSucceeds(setDoc(pumpReference, original));
    const created = await assertSucceeds(getDoc(pumpReference));
    assert.equal(created.data().id, original.id);
    assert.equal(created.data().babyID, original.babyID);
    assert.equal(created.data().createdByUserID, original.createdByUserID);
    assert.equal(created.data().startTime.toDate().getTime(), original.startTime.getTime());
    assert.equal(created.data().createdAt.toDate().getTime(), original.createdAt.getTime());
    assert.equal(created.data().updatedAt.toDate().getTime(), original.updatedAt.getTime());
    assert.equal(created.data().durationSeconds, original.durationSeconds);
    assert.equal(created.data().leftAmountMl, original.leftAmountMl);
    assert.equal(created.data().rightAmountMl, original.rightAmountMl);
    assert.equal(created.data().totalAmountMl, original.totalAmountMl);
    assert.equal(created.data().isPostNursing, original.isPostNursing);
    assert.equal(created.data().notes, original.notes);

    const interval = query(
      collection(db, "babies", babyId, "pumpSessions"),
      where("startTime", ">=", new Date("2026-01-02T00:00:00Z")),
      where("startTime", "<", new Date("2026-01-03T00:00:00Z")),
      orderBy("startTime", "desc"),
    );
    const ranged = await assertSucceeds(getDocs(interval));
    assert.equal(ranged.docs.filter((snapshot) => snapshot.id === pumpID).length, 1);

    const updatedAt = new Date("2026-01-02T11:00:00Z");
    await assertSucceeds(updateDoc(pumpReference, { notes: "Updated", updatedAt }));
    const updated = await assertSucceeds(getDoc(pumpReference));
    assert.equal(updated.data().notes, "Updated");
    assert.equal(updated.data().createdAt.toDate().getTime(), original.createdAt.getTime());
    assert.equal(updated.data().createdByUserID, "caregiver");

    await assertSucceeds(deleteDoc(pumpReference));
    const deleted = await assertSucceeds(getDoc(pumpReference));
    assert.equal(deleted.exists(), false);
  });

  test("pump total-only records preserve unspecified sides", async () => {
    const db = context("caregiver");
    const pumpID = "pump-total-only";
    const pumpReference = doc(db, "babies", babyId, "pumpSessions", pumpID);
    const totalOnly = pumpData(pumpID, "caregiver", {
      leftAmountMl: null,
      rightAmountMl: null,
      totalAmountMl: 72.3456789,
    });

    await assertSucceeds(setDoc(pumpReference, totalOnly));
    const stored = await assertSucceeds(getDoc(pumpReference));
    assert.equal(stored.data().leftAmountMl, null);
    assert.equal(stored.data().rightAmountMl, null);
    assert.equal(stored.data().totalAmountMl, 72.3456789);
  });

  test("sleep sessions preserve an explicit open state and support open-session queries", async () => {
    const db = context("caregiver");
    const openID = "sleep-open";
    const openReference = doc(db, "babies", babyId, "sleepSessions", openID);
    const openSleep = eventData(openID, "caregiver", {
      startTime: new Date("2026-01-02T20:00:00Z"),
      endTime: null,
      notes: "",
    });

    await assertSucceeds(setDoc(openReference, openSleep));
    const stored = await assertSucceeds(getDoc(openReference));
    assert.equal(stored.data().endTime, null);

    const openSessions = query(
      collection(db, "babies", babyId, "sleepSessions"),
      where("endTime", "==", null),
    );
    const queried = await assertSucceeds(getDocs(openSessions));
    assert.equal(queried.docs.filter((snapshot) => snapshot.id === openID).length, 1);

    const endTime = new Date("2026-01-02T21:30:00Z");
    await assertSucceeds(updateDoc(openReference, { endTime, updatedAt: endTime }));
    const completed = await assertSucceeds(getDoc(openReference));
    assert.equal(completed.data().endTime.toDate().getTime(), endTime.getTime());

    await assertSucceeds(deleteDoc(openReference));
  });

  test("checklist items and completions support member CRUD and daily queries", async () => {
    const db = context("caregiver");
    const itemReference = doc(db, "babies", babyId, "checklistItems", "common-bath");
    const item = eventData("common-bath", "caregiver", {
      title: "Bath",
      symbol: "bathtub.fill",
      sortOrder: 0,
      isActive: true,
    });
    await assertSucceeds(setDoc(itemReference, item));

    const eventReference = doc(db, "babies", babyId, "checklistEvents", "bath-event");
    const completion = eventData("bath-event", "caregiver", {
      checklistItemID: "common-bath",
      timestamp: new Date("2026-01-02T12:00:00Z"),
      notes: "",
    });
    await assertSucceeds(setDoc(eventReference, completion));

    const daily = query(
      collection(db, "babies", babyId, "checklistEvents"),
      where("timestamp", ">=", new Date("2026-01-02T00:00:00Z")),
      where("timestamp", "<", new Date("2026-01-03T00:00:00Z")),
      orderBy("timestamp", "desc"),
    );
    const queried = await assertSucceeds(getDocs(daily));
    assert.equal(queried.docs.filter((snapshot) => snapshot.id === "bath-event").length, 1);

    await assertSucceeds(updateDoc(itemReference, { isActive: false, updatedAt: new Date("2026-01-02T13:00:00Z") }));
    await assertSucceeds(deleteDoc(eventReference));
  });

  test("removed member has no baby access", async () => {
    await environment.withSecurityRulesDisabled(async (admin) => {
      await setDoc(doc(admin.firestore(), "babies", babyId, "members", "removed"), memberData("removed", "caregiver", "removed"));
    });
    const db = context("removed");
    await assertFails(getDoc(doc(db, "babies", babyId)));
    await assertFails(getDoc(doc(db, "babies", babyId, "pumpSessions", "seed")));
  });

  test("first baby and owner membership bootstrap batch is allowed", async () => {
    await environment.clearFirestore();
    const db = context("first-owner");
    const batch = writeBatch(db);
    const createdBaby = { ...babyData("first-owner"), id: "first-baby" };
    const createdMember = { ...memberData("first-owner", "owner"), babyID: "first-baby" };
    batch.set(doc(db, "babies", "first-baby"), createdBaby);
    batch.set(doc(db, "babies", "first-baby", "members", "first-owner"), createdMember);
    await assertSucceeds(batch.commit());
  });
});
