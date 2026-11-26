import Foundation

/// Plain-text content for one Timeline event row (design sections 39–45).
/// Views apply category coloring; this struct only carries strings.
struct TimelineRowText: Equatable, Sendable {
    /// Leading time, or (Sleep only) a "start – end" range.
    var time: String
    /// Category-colored primary summary, shown beside `time`.
    var primary: String
    /// Second line, Brown 700. `nil` means a one-line row.
    var secondary: String?
    /// Small uppercase tag (POST NURSING, LAST L/R, SLEEPING). `nil` means none.
    var tag: String?
}

/// Builds per-row display text from a saved record. Pure and
/// Firestore-agnostic; never invents a left/right split or a Breast
/// milk/Formula split that wasn't in the saved data (D3).
enum TimelineRowFormatter {
    /// `rate` is precomputed by the caller (raw mL/hr, via
    /// `PumpRateService.sessionRate`, anchored to the previous pump session).
    static func pump(_ session: PumpSession, unit: VolumeUnit, showRate: Bool, rate: Double?) -> TimelineRowText {
        var primaryParts = [TimelineSummaryFormatter.volumeText(session.totalAmountMl, unit: unit)]
        if showRate {
            if let rate {
                primaryParts.append("\(TimelineSummaryFormatter.volumeText(rate, unit: unit))/hr")
            } else {
                primaryParts.append("– \(unit.rawValue)/hr")
            }
        }

        var secondaryParts = [HomeSummaryService.duration(session.durationSeconds)]
        if let left = session.leftAmountMl, let right = session.rightAmountMl {
            secondaryParts.append(
                "L \(VolumeService.displayString(milliliters: left, unit: unit)) · R \(TimelineSummaryFormatter.volumeText(right, unit: unit))"
            )
        }

        return TimelineRowText(
            time: AppFormatters.time().string(from: session.startTime),
            primary: primaryParts.joined(separator: " · "),
            secondary: secondaryParts.joined(separator: " · "),
            tag: session.isPostNursing ? "POST NURSING" : nil
        )
    }

    static func bottle(_ feed: BottleFeed, unit: VolumeUnit) -> TimelineRowText {
        let secondary: String
        if feed.unspecifiedAmountMl > 0, feed.breastMilkAmountMl == 0, feed.formulaAmountMl == 0 {
            secondary = "Bottle"
        } else {
            var parts: [String] = []
            if feed.breastMilkAmountMl > 0 {
                parts.append("Breast milk \(TimelineSummaryFormatter.volumeText(feed.breastMilkAmountMl, unit: unit))")
            }
            if feed.formulaAmountMl > 0 {
                parts.append("Formula \(TimelineSummaryFormatter.volumeText(feed.formulaAmountMl, unit: unit))")
            }
            secondary = parts.isEmpty ? "Bottle" : parts.joined(separator: " · ")
        }

        return TimelineRowText(
            time: AppFormatters.time().string(from: feed.startTime),
            primary: TimelineSummaryFormatter.volumeText(feed.totalAmountMl, unit: unit),
            secondary: secondary,
            tag: nil
        )
    }

    static func nursing(_ session: NursingSession, estimate: NursingEstimate? = nil, unit: VolumeUnit = .ounces) -> TimelineRowText {
        var secondary = "L \(HomeSummaryService.duration(session.leftDurationSeconds)) · R \(HomeSummaryService.duration(session.rightDurationSeconds))"
        if let estimate {
            let average = TimelineSummaryFormatter.volumeText(estimate.averageMl, unit: unit)
            let minimum = VolumeService.displayString(milliliters: estimate.minimumMl, unit: unit)
            let maximum = TimelineSummaryFormatter.volumeText(estimate.maximumMl, unit: unit)
            secondary += " · Est. \(average) (\(minimum)–\(maximum))"
        }
        return TimelineRowText(
            time: AppFormatters.time().string(from: session.startTime),
            primary: HomeSummaryService.duration(session.totalDurationSeconds),
            secondary: secondary,
            tag: session.lastSide == .left ? "LAST L" : "LAST R"
        )
    }

    static func diaper(_ event: DiaperEvent) -> TimelineRowText {
        var parts: [String] = []
        if let fullness = event.fullness { parts.append(fullness.title) }
        if let size = event.size { parts.append("Size \(size.rawValue)") }
        return TimelineRowText(
            time: AppFormatters.time().string(from: event.startTime),
            primary: event.type.detailTitle,
            secondary: parts.isEmpty ? nil : parts.joined(separator: " · "),
            tag: nil
        )
    }

    static func checklist(_ event: ChecklistEvent, item: ChecklistItem?) -> TimelineRowText {
        TimelineRowText(
            time: AppFormatters.time().string(from: event.timestamp),
            primary: item?.title ?? "Checklist",
            secondary: nil,
            tag: nil
        )
    }

    static func growth(_ measurement: GrowthMeasurement, unitSystem: GrowthUnitSystem = .metric) -> TimelineRowText {
        TimelineRowText(
            time: AppFormatters.time().string(from: measurement.timestamp),
            primary: GrowthFormat.summary(measurement, unitSystem: unitSystem),
            secondary: measurement.notes.isEmpty ? nil : measurement.notes,
            tag: nil
        )
    }

    /// `priorAwake` is computed by the caller via
    /// `TimelineAggregator.priorAwakeDuration` over the full loaded sleep
    /// history (it can span a day boundary), not just this entry.
    static func sleep(_ session: SleepSession, priorAwake: TimeInterval?, now: Date = .now) -> TimelineRowText {
        let startText = AppFormatters.time().string(from: session.startTime)
        let endText = session.isOpen ? "Now" : AppFormatters.time().string(from: session.endTime ?? session.startTime)
        let duration = SleepCalculator.duration(of: session, now: now)
        var details: [String] = []
        if let priorAwake { details.append("Awake \(HomeSummaryService.duration(priorAwake))") }
        if !session.soothingTimes.isEmpty {
            details.append("Needed soothing \(session.soothingTimes.count) time\(session.soothingTimes.count == 1 ? "" : "s")")
        }
        return TimelineRowText(
            time: "\(startText) – \(endText)",
            primary: HomeSummaryService.duration(duration),
            secondary: details.isEmpty ? nil : details.joined(separator: " · "),
            tag: session.isOpen ? "SLEEPING" : nil
        )
    }
}
