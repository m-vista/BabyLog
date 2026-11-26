import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum DataImportClashPolicy: Equatable, Sendable {
    case keepExisting
    case replaceWithImported
}

enum DataTransferRecord: Equatable, Sendable {
    case pump(PumpSession)
    case bottle(BottleFeed)
    case nursing(NursingSession)
    case sleep(SleepSession)
    case diaper(DiaperEvent)
    case checklistItem(ChecklistItem)
    case checklistEvent(ChecklistEvent)

    var key: String {
        switch self {
        case .pump(let value): "pump:\(value.id)"
        case .bottle(let value): "bottle:\(value.id)"
        case .nursing(let value): "nursing:\(value.id)"
        case .sleep(let value): "sleep:\(value.id)"
        case .diaper(let value): "diaper:\(value.id)"
        case .checklistItem(let value): "checklist_item:\(value.id)"
        case .checklistEvent(let value): "checklist_event:\(value.id)"
        }
    }
}

struct DataTransferArchive: Equatable, Sendable {
    var records: [DataTransferRecord]
}

enum DataTransferCSVError: Error, Equatable, LocalizedError {
    case invalidEncoding
    case invalidHeader
    case invalidRow(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding: "The file isn’t valid UTF-8 CSV."
        case .invalidHeader: "The CSV header doesn’t match the BabyLog import format."
        case .invalidRow(let line, let reason): "Row \(line) is invalid: \(reason)"
        }
    }
}

enum DataTransferCSV {
    static let headers = [
        "record_type", "id", "start_time", "end_time", "duration_seconds",
        "left_amount_ml", "right_amount_ml", "total_amount_ml", "is_post_nursing",
        "breast_milk_amount_ml", "formula_amount_ml", "unspecified_amount_ml",
        "left_duration_seconds", "right_duration_seconds", "starting_side", "last_side",
        "diaper_type", "fullness", "size", "checklist_item_id", "title", "symbol",
        "sort_order", "is_active", "notes", "created_at", "updated_at"
    ]

    static var sample: String {
        let guidance = [
            "# BabyLog CSV template. Dates use ISO 8601. Amounts are unrounded milliliters.",
            "# record_type: pump, bottle, nursing, sleep, diaper, checklist_item, checklist_event.",
            "# Leave id blank for a new record. Exported IDs enable keep/replace clash handling."
        ]
        return ([row(headers)] + guidance.map { row([$0]) }).joined(separator: "\n") + "\n"
    }

    static func encode(_ archive: DataTransferArchive) -> String {
        let body = archive.records.map(encodeRecord)
        return ([row(headers)] + body).joined(separator: "\n") + "\n"
    }

    static func decode(_ data: Data, babyID: String, userID: String, now: Date = .now) throws -> DataTransferArchive {
        guard var text = String(data: data, encoding: .utf8) else { throw DataTransferCSVError.invalidEncoding }
        if text.first == "\u{feff}" { text.removeFirst() }
        let rows = parse(text)
        guard let first = rows.first, first == headers else { throw DataTransferCSVError.invalidHeader }
        var records: [DataTransferRecord] = []
        for (offset, values) in rows.dropFirst().enumerated() {
            guard !values.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { continue }
            guard !values[0].trimmingCharacters(in: .whitespaces).hasPrefix("#") else { continue }
            do {
                records.append(try decodeRecord(values, babyID: babyID, userID: userID, now: now))
            } catch {
                let reason: String
                if case .invalidRow(_, let detail) = error as? DataTransferCSVError {
                    reason = detail
                } else {
                    reason = error.localizedDescription
                }
                throw DataTransferCSVError.invalidRow(offset + 2, reason)
            }
        }
        return DataTransferArchive(records: records)
    }

    private static func encodeRecord(_ record: DataTransferRecord) -> String {
        var values = Dictionary(uniqueKeysWithValues: headers.map { ($0, "") })
        func common(type: String, id: String, notes: String, createdAt: Date, updatedAt: Date) {
            values["record_type"] = type; values["id"] = id; values["notes"] = notes
            values["created_at"] = iso(createdAt); values["updated_at"] = iso(updatedAt)
        }
        switch record {
        case .pump(let value):
            common(type: "pump", id: value.id, notes: value.notes, createdAt: value.createdAt, updatedAt: value.updatedAt)
            values["start_time"] = iso(value.startTime); values["duration_seconds"] = number(value.durationSeconds)
            values["left_amount_ml"] = value.leftAmountMl.map(number) ?? ""
            values["right_amount_ml"] = value.rightAmountMl.map(number) ?? ""
            values["total_amount_ml"] = number(value.totalAmountMl); values["is_post_nursing"] = String(value.isPostNursing)
        case .bottle(let value):
            common(type: "bottle", id: value.id, notes: value.notes, createdAt: value.createdAt, updatedAt: value.updatedAt)
            values["start_time"] = iso(value.startTime); values["breast_milk_amount_ml"] = number(value.breastMilkAmountMl)
            values["formula_amount_ml"] = number(value.formulaAmountMl); values["unspecified_amount_ml"] = number(value.unspecifiedAmountMl)
        case .nursing(let value):
            common(type: "nursing", id: value.id, notes: value.notes, createdAt: value.createdAt, updatedAt: value.updatedAt)
            values["start_time"] = iso(value.startTime); values["end_time"] = iso(value.endTime)
            values["left_duration_seconds"] = number(value.leftDurationSeconds); values["right_duration_seconds"] = number(value.rightDurationSeconds)
            values["starting_side"] = value.startingSide.rawValue; values["last_side"] = value.lastSide.rawValue
        case .sleep(let value):
            common(type: "sleep", id: value.id, notes: value.notes, createdAt: value.createdAt, updatedAt: value.updatedAt)
            values["start_time"] = iso(value.startTime); values["end_time"] = value.endTime.map(iso) ?? ""
        case .diaper(let value):
            common(type: "diaper", id: value.id, notes: value.notes, createdAt: value.createdAt, updatedAt: value.updatedAt)
            values["start_time"] = iso(value.startTime); values["diaper_type"] = value.type.rawValue
            values["fullness"] = value.fullness?.rawValue ?? ""; values["size"] = value.size?.rawValue ?? ""
        case .checklistItem(let value):
            common(type: "checklist_item", id: value.id, notes: "", createdAt: value.createdAt, updatedAt: value.updatedAt)
            values["title"] = value.title; values["symbol"] = value.symbol; values["sort_order"] = String(value.sortOrder)
            values["is_active"] = String(value.isActive)
        case .checklistEvent(let value):
            common(type: "checklist_event", id: value.id, notes: value.notes, createdAt: value.createdAt, updatedAt: value.updatedAt)
            values["start_time"] = iso(value.timestamp); values["checklist_item_id"] = value.checklistItemID
        }
        return row(headers.map { values[$0] ?? "" })
    }

    private static func decodeRecord(_ rawValues: [String], babyID: String, userID: String, now: Date) throws -> DataTransferRecord {
        let padded = rawValues + Array(repeating: "", count: max(0, headers.count - rawValues.count))
        let values = Dictionary(uniqueKeysWithValues: zip(headers, padded).map { ($0, $1.trimmingCharacters(in: .whitespacesAndNewlines)) })
        func value(_ key: String) -> String { values[key] ?? "" }
        func required(_ key: String) throws -> String {
            let result = value(key); guard !result.isEmpty else { throw DataTransferCSVError.invalidRow(0, "Missing \(key).") }; return result
        }
        func date(_ key: String, required: Bool = true) throws -> Date? {
            let text = value(key); if text.isEmpty, !required { return nil }
            guard let result = ISO8601DateFormatter.dataTransfer.date(from: text)
                    ?? ISO8601DateFormatter.dataTransferWithoutFractions.date(from: text)
            else { throw DataTransferCSVError.invalidRow(0, "Invalid \(key).") }
            return result
        }
        func double(_ key: String, required: Bool = true) throws -> Double? {
            let text = value(key); if text.isEmpty, !required { return nil }
            guard let result = Double(text), result.isFinite else { throw DataTransferCSVError.invalidRow(0, "Invalid \(key).") }
            return result
        }
        func bool(_ key: String) throws -> Bool {
            switch value(key).lowercased() { case "true", "1", "yes": true; case "false", "0", "no": false; default: throw DataTransferCSVError.invalidRow(0, "Invalid \(key).") }
        }
        let id = value("id").isEmpty ? UUID().uuidString : value("id")
        let createdAt = try date("created_at", required: false) ?? now
        let updatedAt = try date("updated_at", required: false) ?? createdAt
        switch try required("record_type").lowercased() {
        case "pump":
            return .pump(try PumpSession(id: id, babyID: babyID, startTime: try date("start_time")!, durationSeconds: try double("duration_seconds")!, leftAmountMl: try double("left_amount_ml", required: false), rightAmountMl: try double("right_amount_ml", required: false), totalAmountMl: try double("total_amount_ml", required: false) ?? 0, isPostNursing: try bool("is_post_nursing"), notes: value("notes"), createdByUserID: userID, createdAt: createdAt, updatedAt: updatedAt))
        case "bottle":
            return .bottle(try BottleFeed(id: id, babyID: babyID, startTime: try date("start_time")!, breastMilkAmountMl: try double("breast_milk_amount_ml", required: false) ?? 0, formulaAmountMl: try double("formula_amount_ml", required: false) ?? 0, unspecifiedAmountMl: try double("unspecified_amount_ml", required: false) ?? 0, notes: value("notes"), createdByUserID: userID, createdAt: createdAt, updatedAt: updatedAt))
        case "nursing":
            guard let starting = NursingSide(rawValue: value("starting_side")), let last = NursingSide(rawValue: value("last_side")) else { throw DataTransferCSVError.invalidRow(0, "Invalid nursing side.") }
            return .nursing(try NursingSession(id: id, babyID: babyID, startTime: try date("start_time")!, endTime: try date("end_time")!, leftDurationSeconds: try double("left_duration_seconds")!, rightDurationSeconds: try double("right_duration_seconds")!, startingSide: starting, lastSide: last, notes: value("notes"), createdByUserID: userID, createdAt: createdAt, updatedAt: updatedAt))
        case "sleep":
            return .sleep(try SleepSession(id: id, babyID: babyID, startTime: try date("start_time")!, endTime: try date("end_time", required: false), notes: value("notes"), createdByUserID: userID, createdAt: createdAt, updatedAt: updatedAt))
        case "diaper":
            let importedType = value("diaper_type") == "mixed" ? "both" : value("diaper_type")
            guard let type = DiaperType(rawValue: importedType) else { throw DataTransferCSVError.invalidRow(0, "Invalid diaper_type.") }
            let importedFullness: String
            switch value("fullness") {
            case "small": importedFullness = "light"
            case "large": importedFullness = "heavy"
            default: importedFullness = value("fullness")
            }
            let fullness = importedFullness.isEmpty ? nil : DiaperFullness(rawValue: importedFullness)
            let size = value("size").isEmpty ? nil : DiaperSize(rawValue: value("size"))
            guard importedFullness.isEmpty || fullness != nil, value("size").isEmpty || size != nil else { throw DataTransferCSVError.invalidRow(0, "Invalid fullness or size.") }
            return .diaper(try DiaperEvent(id: id, babyID: babyID, startTime: try date("start_time")!, type: type, fullness: fullness, size: size, notes: value("notes"), createdByUserID: userID, createdAt: createdAt, updatedAt: updatedAt))
        case "checklist_item":
            guard let order = Int(value("sort_order")) else { throw DataTransferCSVError.invalidRow(0, "Invalid sort_order.") }
            return .checklistItem(try ChecklistItem(id: id, babyID: babyID, title: try required("title"), symbol: try required("symbol"), sortOrder: order, isActive: try bool("is_active"), createdByUserID: userID, createdAt: createdAt, updatedAt: updatedAt))
        case "checklist_event":
            return .checklistEvent(try ChecklistEvent(id: id, babyID: babyID, checklistItemID: try required("checklist_item_id"), timestamp: try date("start_time")!, notes: value("notes"), createdByUserID: userID, createdAt: createdAt, updatedAt: updatedAt))
        default: throw DataTransferCSVError.invalidRow(0, "Unknown record_type.")
        }
    }

    private static func row(_ values: [String]) -> String { values.map(escape).joined(separator: ",") }
    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    private static func number(_ value: Double) -> String { String(value) }
    private static func iso(_ date: Date) -> String { ISO8601DateFormatter.dataTransfer.string(from: date) }

    private static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []; var row: [String] = []; var field = ""; var quoted = false
        let characters = Array(text); var index = 0
        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"", index + 1 < characters.count, characters[index + 1] == "\"" { field.append("\""); index += 1 }
                else if character == "\"" { quoted = false }
                else { field.append(character) }
            } else if character == "\"" { quoted = true }
            else if character == "," { row.append(field); field = "" }
            else if character == "\n" { row.append(field); rows.append(row); row = []; field = "" }
            else if character != "\r" { field.append(character) }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}

struct CSVTransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else { throw DataTransferCSVError.invalidEncoding }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private extension ISO8601DateFormatter {
    static let dataTransfer: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    static let dataTransferWithoutFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
