import Foundation
import Testing
@testable import BabyLog

struct DataTransferCSVTests {
    private let timestamp = Date(timeIntervalSince1970: 1_700_000_000.125)

    @Test func archiveRoundTripsEveryRecordTypeAndQuotedNotes() throws {
        let archive = DataTransferArchive(records: [
            .pump(try PumpSession(id: "pump", babyID: "baby", startTime: timestamp, durationSeconds: 600, leftAmountMl: nil, rightAmountMl: nil, totalAmountMl: 42.123456789, isPostNursing: true, notes: "comma, quote \" and\nline", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)),
            .bottle(try BottleFeed(id: "bottle", babyID: "baby", startTime: timestamp, breastMilkAmountMl: 20, formulaAmountMl: 0, unspecifiedAmountMl: 0, notes: "", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)),
            .nursing(try NursingSession(id: "nursing", babyID: "baby", startTime: timestamp, endTime: timestamp.addingTimeInterval(300), leftDurationSeconds: 120, rightDurationSeconds: 180, startingSide: .left, lastSide: .right, notes: "", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)),
            .sleep(try SleepSession(id: "sleep", babyID: "baby", startTime: timestamp, endTime: timestamp.addingTimeInterval(900), notes: "", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)),
            .diaper(try DiaperEvent(id: "diaper", babyID: "baby", startTime: timestamp, type: .both, fullness: .heavy, size: .two, notes: "", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)),
            .checklistItem(try ChecklistItem(id: "item", babyID: "baby", title: "Bath", symbol: ChecklistSymbol.bath.rawValue, sortOrder: 0, isActive: true, createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)),
            .checklistEvent(try ChecklistEvent(id: "event", babyID: "baby", checklistItemID: "item", timestamp: timestamp, notes: "Done", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp))
        ])

        let decoded = try DataTransferCSV.decode(
            Data(DataTransferCSV.encode(archive).utf8),
            babyID: "baby",
            userID: "user"
        )

        #expect(decoded == archive)
        guard case .pump(let pump) = decoded.records[0] else { Issue.record("Expected pump"); return }
        #expect(pump.leftAmountMl == nil)
        #expect(pump.rightAmountMl == nil)
        #expect(pump.totalAmountMl.bitPattern == 42.123456789.bitPattern)
    }

    @Test func importRemapsBabyAndCaregiverAndGeneratesBlankID() throws {
        var columns = Array(repeating: "", count: DataTransferCSV.headers.count)
        func set(_ key: String, _ value: String) { columns[DataTransferCSV.headers.firstIndex(of: key)!] = value }
        set("record_type", "bottle"); set("start_time", "2026-10-06T12:00:00Z")
        set("breast_milk_amount_ml", "30"); set("formula_amount_ml", "0"); set("unspecified_amount_ml", "0")
        let csv = DataTransferCSV.headers.joined(separator: ",") + "\n" + columns.joined(separator: ",") + "\n"

        let archive = try DataTransferCSV.decode(Data(csv.utf8), babyID: "selected-baby", userID: "current-user", now: timestamp)
        guard case .bottle(let bottle) = archive.records.first else { Issue.record("Expected bottle"); return }
        #expect(UUID(uuidString: bottle.id) != nil)
        #expect(bottle.babyID == "selected-baby")
        #expect(bottle.createdByUserID == "current-user")
    }

    @Test func sampleTemplateParsesAsAnEmptyArchive() throws {
        let archive = try DataTransferCSV.decode(Data(DataTransferCSV.sample.utf8), babyID: "baby", userID: "user")
        #expect(archive.records.isEmpty)
    }

    @Test func blankBottleComponentsDecodeAsZero() throws {
        var columns = Array(repeating: "", count: DataTransferCSV.headers.count)
        func set(_ key: String, _ value: String) { columns[DataTransferCSV.headers.firstIndex(of: key)!] = value }
        set("record_type", "bottle")
        set("start_time", "2026-06-24T05:45:00-07:00")
        set("breast_milk_amount_ml", "2.9574")
        let csv = DataTransferCSV.headers.joined(separator: ",") + "\n" + columns.joined(separator: ",") + "\n"

        let archive = try DataTransferCSV.decode(Data(csv.utf8), babyID: "baby", userID: "user", now: timestamp)
        guard case .bottle(let bottle) = archive.records.first else { Issue.record("Expected bottle"); return }
        #expect(bottle.breastMilkAmountMl == 2.9574)
        #expect(bottle.formulaAmountMl == 0)
        #expect(bottle.unspecifiedAmountMl == 0)
    }

    @Test func blankBottleSplitComponentsSupportUnspecifiedAmount() throws {
        var columns = Array(repeating: "", count: DataTransferCSV.headers.count)
        func set(_ key: String, _ value: String) { columns[DataTransferCSV.headers.firstIndex(of: key)!] = value }
        set("record_type", "bottle")
        set("start_time", "2026-06-24T05:45:00-07:00")
        set("unspecified_amount_ml", "30")
        let csv = DataTransferCSV.headers.joined(separator: ",") + "\n" + columns.joined(separator: ",") + "\n"

        let archive = try DataTransferCSV.decode(Data(csv.utf8), babyID: "baby", userID: "user", now: timestamp)
        guard case .bottle(let bottle) = archive.records.first else { Issue.record("Expected bottle"); return }
        #expect(bottle.breastMilkAmountMl == 0)
        #expect(bottle.formulaAmountMl == 0)
        #expect(bottle.unspecifiedAmountMl == 30)
    }

    @Test func malformedNonblankBottleAmountStillFails() {
        var columns = Array(repeating: "", count: DataTransferCSV.headers.count)
        func set(_ key: String, _ value: String) { columns[DataTransferCSV.headers.firstIndex(of: key)!] = value }
        set("record_type", "bottle")
        set("start_time", "2026-06-24T05:45:00-07:00")
        set("formula_amount_ml", "not-a-number")
        let csv = DataTransferCSV.headers.joined(separator: ",") + "\n" + columns.joined(separator: ",") + "\n"

        #expect(throws: DataTransferCSVError.invalidRow(2, "Invalid formula_amount_ml.")) {
            try DataTransferCSV.decode(Data(csv.utf8), babyID: "baby", userID: "user", now: timestamp)
        }
    }

    @Test func importAliasesNormalizeLegacyDiaperValues() throws {
        var columns = Array(repeating: "", count: DataTransferCSV.headers.count)
        func set(_ key: String, _ value: String) { columns[DataTransferCSV.headers.firstIndex(of: key)!] = value }
        set("record_type", "diaper")
        set("start_time", "2026-06-25T10:50:00-07:00")
        set("diaper_type", "mixed")
        set("fullness", "small")
        let smallCSV = DataTransferCSV.headers.joined(separator: ",") + "\n" + columns.joined(separator: ",") + "\n"

        let smallArchive = try DataTransferCSV.decode(Data(smallCSV.utf8), babyID: "baby", userID: "user", now: timestamp)
        guard case .diaper(let small) = smallArchive.records.first else { Issue.record("Expected diaper"); return }
        #expect(small.type == .both)
        #expect(small.fullness == .light)

        set("fullness", "large")
        let largeCSV = DataTransferCSV.headers.joined(separator: ",") + "\n" + columns.joined(separator: ",") + "\n"
        let largeArchive = try DataTransferCSV.decode(Data(largeCSV.utf8), babyID: "baby", userID: "user", now: timestamp)
        guard case .diaper(let large) = largeArchive.records.first else { Issue.record("Expected diaper"); return }
        #expect(large.type == .both)
        #expect(large.fullness == .heavy)
    }

    @Test func blankPumpTotalDecodesAsZero() throws {
        var columns = Array(repeating: "", count: DataTransferCSV.headers.count)
        func set(_ key: String, _ value: String) { columns[DataTransferCSV.headers.firstIndex(of: key)!] = value }
        set("record_type", "pump")
        set("start_time", "2026-07-04T13:09:00-07:00")
        set("duration_seconds", "900")
        set("is_post_nursing", "false")
        let csv = DataTransferCSV.headers.joined(separator: ",") + "\n" + columns.joined(separator: ",") + "\n"

        let archive = try DataTransferCSV.decode(Data(csv.utf8), babyID: "baby", userID: "user", now: timestamp)
        guard case .pump(let pump) = archive.records.first else { Issue.record("Expected pump"); return }
        #expect(pump.totalAmountMl == 0)
        #expect(pump.leftAmountMl == nil)
        #expect(pump.rightAmountMl == nil)
    }

    @Test func unknownDiaperAliasesStillFail() {
        var columns = Array(repeating: "", count: DataTransferCSV.headers.count)
        func set(_ key: String, _ value: String) { columns[DataTransferCSV.headers.firstIndex(of: key)!] = value }
        set("record_type", "diaper")
        set("start_time", "2026-06-25T10:50:00-07:00")
        set("diaper_type", "unknown")
        let csv = DataTransferCSV.headers.joined(separator: ",") + "\n" + columns.joined(separator: ",") + "\n"

        #expect(throws: DataTransferCSVError.invalidRow(2, "Invalid diaper_type.")) {
            try DataTransferCSV.decode(Data(csv.utf8), babyID: "baby", userID: "user", now: timestamp)
        }
    }

    @Test func malformedRowReportsItsPhysicalRow() {
        let csv = DataTransferCSV.headers.joined(separator: ",") + "\npump,id\n"
        #expect(throws: DataTransferCSVError.invalidRow(2, "Invalid start_time.")) {
            try DataTransferCSV.decode(Data(csv.utf8), babyID: "baby", userID: "user")
        }
    }

    @Test func keepExistingSkipsExistingAndDuplicateImportedIDs() throws {
        let bottle = try BottleFeed(id: "same", babyID: "baby", startTime: timestamp, breastMilkAmountMl: 10, formulaAmountMl: 0, unspecifiedAmountMl: 0, notes: "", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)
        let records = [DataTransferRecord.bottle(bottle), .bottle(bottle)]
        let againstExisting = DataImportPlanner.plan(records: records, existingKeys: ["bottle:same"], policy: .keepExisting)
        #expect(againstExisting.records.isEmpty)
        #expect(againstExisting.skipped == 2)

        let duplicateImport = DataImportPlanner.plan(records: records, existingKeys: [], policy: .keepExisting)
        #expect(duplicateImport.records.count == 1)
        #expect(duplicateImport.skipped == 1)
    }

    @Test func replacePolicyWritesEveryImportedRecord() throws {
        let bottle = try BottleFeed(id: "same", babyID: "baby", startTime: timestamp, breastMilkAmountMl: 10, formulaAmountMl: 0, unspecifiedAmountMl: 0, notes: "", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)
        let plan = DataImportPlanner.plan(records: [.bottle(bottle)], existingKeys: ["bottle:same"], policy: .replaceWithImported)
        #expect(plan.records.count == 1)
        #expect(plan.skipped == 0)
    }

    @Test func replacementPreservesFirestoreImmutableIdentity() throws {
        let current = try BottleFeed(id: "same", babyID: "baby", startTime: timestamp, breastMilkAmountMl: 10, formulaAmountMl: 0, unspecifiedAmountMl: 0, notes: "old", createdByUserID: "original-user", createdAt: timestamp, updatedAt: timestamp)
        let imported = try BottleFeed(id: "same", babyID: "baby", startTime: timestamp.addingTimeInterval(60), breastMilkAmountMl: 40, formulaAmountMl: 0, unspecifiedAmountMl: 0, notes: "new", createdByUserID: "importing-user", createdAt: timestamp.addingTimeInterval(50), updatedAt: timestamp.addingTimeInterval(60))

        let replacement = try DataTransferRecord.bottle(imported)
            .preservingImmutableIdentity(from: .bottle(current))
        guard case .bottle(let bottle) = replacement else { Issue.record("Expected bottle"); return }
        #expect(bottle.createdByUserID == current.createdByUserID)
        #expect(bottle.createdAt == current.createdAt)
        #expect(bottle.breastMilkAmountMl == imported.breastMilkAmountMl)
        #expect(bottle.notes == "new")
    }
}
