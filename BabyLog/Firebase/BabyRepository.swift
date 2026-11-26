import Foundation
import FirebaseFirestore

struct BabyRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func createFirstBaby(name: String, birthDate: Date, userID: String) async throws -> BabyAccess {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw BabyRepositoryError.missingName }
        guard birthDate <= Date() else { throw BabyRepositoryError.futureBirthDate }

        let babyID = UUID().uuidString
        let now = Date()
        let baby = Baby(
            id: babyID,
            name: trimmedName,
            birthDate: birthDate,
            createdByUserID: userID,
            createdAt: now,
            updatedAt: now
        )
        let membership = BabyMembership(
            id: userID,
            babyID: babyID,
            userID: userID,
            role: .owner,
            status: .active,
            createdAt: now,
            updatedAt: now
        )

        let babyReference = db.collection("babies").document(babyID)
        let membershipReference = babyReference.collection("members").document(userID)
        let batch = db.batch()
        try batch.setData(from: baby, forDocument: babyReference)
        try batch.setData(from: membership, forDocument: membershipReference)
        try await batch.commit()
        return BabyAccess(baby: baby, membership: membership)
    }

    func babyAccesses(for userID: String) async throws -> [BabyAccess] {
        let snapshots = try await db.collectionGroup("members")
            .whereField("userID", isEqualTo: userID)
            .getDocuments()

        let memberships = Self.activeMemberships(
            from: try snapshots.documents.map { try $0.data(as: BabyMembership.self) }
        )

        return try await withThrowingTaskGroup(of: BabyAccess.self) { group in
            for membership in memberships {
                group.addTask {
                    let snapshot = try await db.collection("babies")
                        .document(membership.babyID)
                        .getDocument()
                    return BabyAccess(
                        baby: try snapshot.data(as: Baby.self),
                        membership: membership
                    )
                }
            }

            var accesses: [BabyAccess] = []
            for try await access in group {
                accesses.append(access)
            }
            return accesses.sorted { $0.baby.createdAt < $1.baby.createdAt }
        }
    }

    static func activeMemberships(from memberships: [BabyMembership]) -> [BabyMembership] {
        memberships.filter { $0.status == .active }
    }

    func addMember(
        userID: String,
        role: BabyMembership.Role,
        to babyID: String
    ) async throws {
        guard role != .owner else { throw BabyRepositoryError.ownerCannotBeGranted }
        let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserID.isEmpty else { throw BabyRepositoryError.missingUserID }

        let now = Date()
        let membership = BabyMembership(
            id: trimmedUserID,
            babyID: babyID,
            userID: trimmedUserID,
            role: role,
            status: .active,
            createdAt: now,
            updatedAt: now
        )
        try db.collection("babies").document(babyID)
            .collection("members").document(trimmedUserID)
            .setData(from: membership)
    }

    func update(_ baby: Baby, at date: Date = .now) async throws -> Baby {
        var updated = baby
        updated.name = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.name.isEmpty else { throw BabyRepositoryError.missingName }
        guard updated.birthDate <= date else { throw BabyRepositoryError.futureBirthDate }
        if updated.usesCorrectedDate == true, updated.dueDate == nil {
            throw BabyRepositoryError.missingDueDate
        }
        guard (0..<1_440).contains(updated.nightStartMinutes), (0..<1_440).contains(updated.nightEndMinutes) else {
            throw BabyRepositoryError.invalidNightWindow
        }
        updated.updatedAt = date
        try await db.collection("babies").document(updated.id).setData(Firestore.Encoder().encode(updated))
        return updated
    }
}

enum BabyRepositoryError: Error, Equatable {
    case missingName
    case futureBirthDate
    case missingUserID
    case ownerCannotBeGranted
    case invalidNightWindow
    case missingDueDate
}

enum BabyErrorPresenter {
    static func message(for error: Error) -> String {
        switch error as? BabyRepositoryError {
        case .missingName:
            return "Enter your baby’s name."
        case .futureBirthDate:
            return "Birth date can’t be in the future."
        case .missingUserID:
            return "Enter a user ID."
        case .ownerCannotBeGranted:
            return "Owner access can’t be granted here."
        case .invalidNightWindow:
            return "Choose valid night start and end times."
        case .missingDueDate:
            return "Choose a due date for corrected age."
        case nil:
            let nsError = error as NSError
            if nsError.domain == FirestoreErrorDomain,
               nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                return "You don’t have permission to make that change."
            }
            return "Something went wrong. Try again."
        }
    }
}
