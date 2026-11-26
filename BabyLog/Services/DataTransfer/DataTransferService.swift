import Foundation

struct DataImportResult: Equatable, Sendable {
    let imported: Int
    let skipped: Int
}

enum DataImportPlanner {
    static func plan(
        records: [DataTransferRecord],
        existingKeys: Set<String>,
        policy: DataImportClashPolicy
    ) -> (records: [DataTransferRecord], skipped: Int) {
        guard policy == .keepExisting else { return (records, 0) }
        var seen = existingKeys
        var selected: [DataTransferRecord] = []
        var skipped = 0
        for record in records {
            if seen.contains(record.key) { skipped += 1 }
            else { selected.append(record); seen.insert(record.key) }
        }
        return (selected, skipped)
    }
}

@MainActor
struct DataTransferService {
    let environment: AppEnvironment
    let access: BabyAccess

    func exportArchive(now: Date = .now) async throws -> DataTransferArchive {
        let interval = exportInterval(now: now)
        async let pumps = first(environment.pumpRepository.observe(babyID: access.baby.id, interval: interval))
        async let bottles = first(environment.bottleRepository.observe(babyID: access.baby.id, interval: interval))
        async let nursing = first(environment.nursingRepository.observe(babyID: access.baby.id, interval: interval))
        async let sleep = first(environment.sleepRepository.observe(babyID: access.baby.id, interval: interval))
        async let diapers = first(environment.diaperRepository.observe(babyID: access.baby.id, interval: interval))
        async let checklistItems = first(environment.checklistRepository.observeItems(babyID: access.baby.id, includeInactive: true))
        async let checklistEvents = first(environment.checklistRepository.observeEvents(babyID: access.baby.id, interval: interval))

        let values = try await (pumps, bottles, nursing, sleep, diapers, checklistItems, checklistEvents)
        var records: [DataTransferRecord] = []
        records += (values.0 ?? []).map(DataTransferRecord.pump)
        records += (values.1 ?? []).map(DataTransferRecord.bottle)
        records += (values.2 ?? []).map(DataTransferRecord.nursing)
        records += (values.3 ?? []).map(DataTransferRecord.sleep)
        records += (values.4 ?? []).map(DataTransferRecord.diaper)
        records += (values.5 ?? []).map(DataTransferRecord.checklistItem)
        records += (values.6 ?? []).map(DataTransferRecord.checklistEvent)
        return DataTransferArchive(records: records.sorted { recordDate($0) < recordDate($1) })
    }

    func importArchive(
        _ archive: DataTransferArchive,
        clashPolicy: DataImportClashPolicy,
        now: Date = .now
    ) async throws -> DataImportResult {
        let existing = try await exportArchive(now: now)
        let existingKeys = Set(existing.records.map(\.key))
        let existingByKey = Dictionary(uniqueKeysWithValues: existing.records.map { ($0.key, $0) })
        var imported = 0

        // Items go first so imported completion events can resolve their item.
        let ordered = archive.records.sorted { lhs, rhs in
            if case .checklistItem = lhs, case .checklistItem = rhs { return false }
            if case .checklistItem = lhs { return true }
            if case .checklistItem = rhs { return false }
            return recordDate(lhs) < recordDate(rhs)
        }
        let identitySafeRecords: [DataTransferRecord]
        if clashPolicy == .replaceWithImported {
            identitySafeRecords = try ordered.map { imported in
                guard let current = existingByKey[imported.key] else { return imported }
                return try imported.preservingImmutableIdentity(from: current)
            }
        } else {
            identitySafeRecords = ordered
        }
        let plan = DataImportPlanner.plan(records: identitySafeRecords, existingKeys: existingKeys, policy: clashPolicy)
        for record in plan.records {
            try await write(record)
            imported += 1
        }
        return DataImportResult(imported: imported, skipped: plan.skipped)
    }

    private func write(_ record: DataTransferRecord) async throws {
        switch record {
        case .pump(let value): try await environment.pumpRepository.create(value)
        case .bottle(let value): try await environment.bottleRepository.create(value)
        case .nursing(let value): try await environment.nursingRepository.create(value)
        case .sleep(let value): try await environment.sleepRepository.create(value)
        case .diaper(let value): try await environment.diaperRepository.create(value)
        case .checklistItem(let value): try await environment.checklistRepository.createItem(value)
        case .checklistEvent(let value): try await environment.checklistRepository.createEvent(value)
        }
    }

    private func exportInterval(now: Date) -> DateInterval {
        let start = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -1, to: access.baby.birthDate) ?? access.baby.birthDate
        let end = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    private func first<T>(_ stream: AsyncThrowingStream<T, Error>) async throws -> T? {
        for try await value in stream { return value }
        return nil
    }

    private func recordDate(_ record: DataTransferRecord) -> Date {
        switch record {
        case .pump(let value): value.startTime
        case .bottle(let value): value.startTime
        case .nursing(let value): value.startTime
        case .sleep(let value): value.startTime
        case .diaper(let value): value.startTime
        case .checklistItem(let value): value.createdAt
        case .checklistEvent(let value): value.timestamp
        }
    }
}

extension DataTransferRecord {
    func preservingImmutableIdentity(from existing: DataTransferRecord) throws -> DataTransferRecord {
        switch (self, existing) {
        case (.pump(let imported), .pump(let current)):
            return .pump(try PumpSession(id: imported.id, babyID: imported.babyID, startTime: imported.startTime, durationSeconds: imported.durationSeconds, leftAmountMl: imported.leftAmountMl, rightAmountMl: imported.rightAmountMl, totalAmountMl: imported.totalAmountMl, isPostNursing: imported.isPostNursing, notes: imported.notes, createdByUserID: current.createdByUserID, createdAt: current.createdAt, updatedAt: imported.updatedAt))
        case (.bottle(let imported), .bottle(let current)):
            return .bottle(try BottleFeed(id: imported.id, babyID: imported.babyID, startTime: imported.startTime, breastMilkAmountMl: imported.breastMilkAmountMl, formulaAmountMl: imported.formulaAmountMl, unspecifiedAmountMl: imported.unspecifiedAmountMl, notes: imported.notes, createdByUserID: current.createdByUserID, createdAt: current.createdAt, updatedAt: imported.updatedAt))
        case (.nursing(let imported), .nursing(let current)):
            return .nursing(try NursingSession(id: imported.id, babyID: imported.babyID, startTime: imported.startTime, endTime: imported.endTime, leftDurationSeconds: imported.leftDurationSeconds, rightDurationSeconds: imported.rightDurationSeconds, startingSide: imported.startingSide, lastSide: imported.lastSide, notes: imported.notes, createdByUserID: current.createdByUserID, createdAt: current.createdAt, updatedAt: imported.updatedAt))
        case (.sleep(let imported), .sleep(let current)):
            return .sleep(try SleepSession(id: imported.id, babyID: imported.babyID, startTime: imported.startTime, endTime: imported.endTime, notes: imported.notes, createdByUserID: current.createdByUserID, createdAt: current.createdAt, updatedAt: imported.updatedAt))
        case (.diaper(let imported), .diaper(let current)):
            return .diaper(try DiaperEvent(id: imported.id, babyID: imported.babyID, startTime: imported.startTime, type: imported.type, fullness: imported.fullness, size: imported.size, notes: imported.notes, createdByUserID: current.createdByUserID, createdAt: current.createdAt, updatedAt: imported.updatedAt))
        case (.checklistItem(let imported), .checklistItem(let current)):
            return .checklistItem(try ChecklistItem(id: imported.id, babyID: imported.babyID, title: imported.title, symbol: imported.symbol, sortOrder: imported.sortOrder, isActive: imported.isActive, createdByUserID: current.createdByUserID, createdAt: current.createdAt, updatedAt: imported.updatedAt))
        case (.checklistEvent(let imported), .checklistEvent(let current)):
            return .checklistEvent(try ChecklistEvent(id: imported.id, babyID: imported.babyID, checklistItemID: imported.checklistItemID, timestamp: imported.timestamp, notes: imported.notes, createdByUserID: current.createdByUserID, createdAt: current.createdAt, updatedAt: imported.updatedAt))
        default:
            return self
        }
    }
}
