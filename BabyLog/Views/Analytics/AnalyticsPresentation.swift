import SwiftUI

struct AnalyticsStat: Identifiable { let id: String; let title: String; let value: String; let subtitle: String; var tint: Color? = nil }
struct AnalyticsBreakdown: Identifiable { let id: String; let label: String; let fraction: Double; let text: String }

struct AnalyticsPresentation {
    let label: String; let value: String; let unit: String; let chartUnit: String; let subtitle: String
    let points: [AnalyticsPoint]; let stats: [AnalyticsStat]; let breakdownTitle: String; let breakdown: [AnalyticsBreakdown]

    init(category: TrackingCategory, snapshot: AnalyticsSnapshot, unit: VolumeUnit) {
        let days = Double(snapshot.dayCount)
        switch category {
        case .feed:
            let valueMl = snapshot.feed.bottleAmountMl / days
            label = snapshot.dayCount == 1 ? "BOTTLE TODAY" : "AVG DAILY BOTTLE"; value = AnalyticsFormat.volume(valueMl, unit); self.unit = unit.rawValue; chartUnit = unit.rawValue
            subtitle = "\(AnalyticsFormat.decimal(Double(snapshot.feed.bottleCount) / days)) feeds a day · \(AnalyticsFormat.duration(snapshot.feed.nursingSeconds / days)) nursing a day"
            points = AnalyticsFormat.volumePoints(snapshot.feed.dailyBottleMl, unit: unit)
            stats = [
                .init(id: "feeds", title: "Feeds / day", value: AnalyticsFormat.decimal(Double(snapshot.feed.bottleCount + snapshot.feed.nursingCount) / days), subtitle: "Bottle \(snapshot.feed.bottleCount) · Nursing \(snapshot.feed.nursingCount)"),
                .init(id: "average", title: "Avg bottle", value: "\(AnalyticsFormat.volume(snapshot.feed.bottleCount == 0 ? 0 : snapshot.feed.bottleAmountMl / Double(snapshot.feed.bottleCount), unit)) \(unit.rawValue)", subtitle: "Across \(snapshot.feed.bottleCount) bottles"),
                .init(id: "nursing", title: "Nursing / day", value: AnalyticsFormat.duration(snapshot.feed.nursingSeconds / days), subtitle: "\(snapshot.feed.nursingCount) sessions"),
                .init(id: "gap", title: "Longest gap", value: AnalyticsFormat.duration(snapshot.feed.longestGapSeconds), subtitle: "Between feeds")]
            breakdownTitle = "BY TYPE"
            let maxValue = max(snapshot.feed.breastMilkMl, snapshot.feed.formulaMl, snapshot.feed.unspecifiedMl, 1)
            breakdown = [("Breast milk", snapshot.feed.breastMilkMl), ("Formula", snapshot.feed.formulaMl), ("Unspecified", snapshot.feed.unspecifiedMl)].map { .init(id: $0.0, label: $0.0, fraction: $0.1 / maxValue, text: "\(AnalyticsFormat.volume($0.1, unit)) \(unit.rawValue)") }
        case .sleep:
            label = snapshot.dayCount == 1 ? "TOTAL SLEEP" : "AVG DAILY SLEEP"; value = AnalyticsFormat.duration(snapshot.sleep.totalSeconds / days); self.unit = ""; chartUnit = "hours"
            subtitle = "Naps \(AnalyticsFormat.duration(snapshot.sleep.napSeconds)) · Night \(AnalyticsFormat.duration(snapshot.sleep.nightSeconds))"; points = snapshot.sleep.dailySeconds.map { AnalyticsPoint(id: $0.id, value: $0.value / 3_600) }
            stats = [.init(id:"naps",title:"Naps",value:snapshot.dayCount == 1 ? "\(snapshot.sleep.napCount)" : AnalyticsFormat.decimal(Double(snapshot.sleep.napCount)/days),subtitle:AnalyticsFormat.duration(snapshot.sleep.napSeconds)), .init(id:"night",title:"Night",value:AnalyticsFormat.duration(snapshot.sleep.nightSeconds/days),subtitle:"Average per day"), .init(id:"long",title:"Longest stretch",value:AnalyticsFormat.duration(snapshot.sleep.longestStretchSeconds),subtitle:"Longest sleep"), .init(id:"awake",title:"Avg awake",value:AnalyticsFormat.duration(snapshot.sleep.averageAwakeSeconds),subtitle:"Between sleeps")]
            breakdownTitle = "NAPS VS NIGHT"; let total=max(snapshot.sleep.totalSeconds,1); breakdown=[.init(id:"naps",label:"Naps",fraction:snapshot.sleep.napSeconds/total,text:AnalyticsFormat.duration(snapshot.sleep.napSeconds)),.init(id:"night",label:"Night",fraction:snapshot.sleep.nightSeconds/total,text:AnalyticsFormat.duration(snapshot.sleep.nightSeconds))]
        case .diaper:
            label = snapshot.dayCount == 1 ? "DIAPERS TODAY" : "AVG PER DAY"; value = AnalyticsFormat.decimal(Double(snapshot.diaper.changes)/days); self.unit="changes"; chartUnit="changes"; subtitle="Wet \(snapshot.diaper.wet) · Dirty \(snapshot.diaper.dirty) · \(snapshot.diaper.both) was both"; points=snapshot.diaper.dailyChanges
            stats=[.init(id:"wet",title:"Wet / day",value:AnalyticsFormat.decimal(Double(snapshot.diaper.wet)/days),subtitle:"\(snapshot.diaper.wet) total",tint:category.style.text),.init(id:"dirty",title:"Dirty / day",value:AnalyticsFormat.decimal(Double(snapshot.diaper.dirty)/days),subtitle:"\(snapshot.diaper.dirty) total"),.init(id:"both",title:"Wet & dirty",value:"\(snapshot.diaper.both)",subtitle:"Counted in both"),.init(id:"size",title:"Size",value:snapshot.diaper.mostUsedSize?.rawValue ?? "–",subtitle:"Most used")]
            breakdownTitle="FULLNESS"; let maxValue=Double(max(snapshot.diaper.fullness.values.max() ?? 0,1)); breakdown=DiaperFullness.allCases.map{.init(id:$0.rawValue,label:$0.title,fraction:Double(snapshot.diaper.fullness[$0,default:0])/maxValue,text:"\(snapshot.diaper.fullness[$0,default:0])")}
        case .pump:
            label=snapshot.dayCount == 1 ? "PUMPED TODAY" : "AVG DAILY OUTPUT"; value=AnalyticsFormat.volume(snapshot.pump.totalMl/days,unit); self.unit=unit.rawValue; chartUnit=unit.rawValue; subtitle="\(AnalyticsFormat.decimal(Double(snapshot.pump.sessionCount)/days)) sessions a day"; points=AnalyticsFormat.volumePoints(snapshot.pump.dailyMl, unit: unit)
            stats=[.init(id:"rate",title:"Avg clean rate",value:snapshot.pump.cleanRateMlPerHour.map{"\(AnalyticsFormat.volume($0,unit)) \(unit.rawValue)/hr"} ?? "–",subtitle:"Excludes post nursing",tint:category.style.text),.init(id:"sessions",title:"Sessions",value:"\(snapshot.pump.sessionCount)",subtitle:"\(snapshot.pump.cleanCount) clean · \(snapshot.pump.postNursingCount) post nursing"),.init(id:"time",title:"Total time",value:AnalyticsFormat.duration(snapshot.pump.totalSeconds),subtitle:"Across all sessions"),.init(id:"ratio",title:"Left : right",value:"\(AnalyticsFormat.percentRatio(snapshot.pump.leftMl,snapshot.pump.rightMl))",subtitle:"Specified sides only")]
            breakdownTitle="BY TYPE"; let maxValue=max(snapshot.pump.cleanMl,snapshot.pump.totalMl-snapshot.pump.cleanMl,1); breakdown=[.init(id:"clean",label:"Clean",fraction:snapshot.pump.cleanMl/maxValue,text:"\(AnalyticsFormat.volume(snapshot.pump.cleanMl,unit)) \(unit.rawValue)"),.init(id:"post",label:"Post nursing",fraction:(snapshot.pump.totalMl-snapshot.pump.cleanMl)/maxValue,text:"\(AnalyticsFormat.volume(snapshot.pump.totalMl-snapshot.pump.cleanMl,unit)) \(unit.rawValue)")]
        case .other:
            label=snapshot.dayCount == 1 ? "DONE TODAY" : "COMPLETION"; value=AnalyticsFormat.percent(snapshot.other.completion); self.unit=""; chartUnit="%"; subtitle="\(snapshot.other.completedCount) of \(snapshot.other.possibleCount) items"; points=snapshot.other.dailyCompletion.map { AnalyticsPoint(id: $0.id, value: $0.value * 100) }
            stats=Array(snapshot.other.items.prefix(4)).map{.init(id:$0.id,title:$0.title,value:"\($0.completedDays) of \($0.possibleDays)",subtitle:AnalyticsFormat.percent($0.completion))}; breakdownTitle="BY ITEM"; breakdown=snapshot.other.items.map{.init(id:$0.id,label:$0.title,fraction:$0.completion,text:AnalyticsFormat.percent($0.completion))}
        }
    }
}

enum AnalyticsFormat {
    static func chartValue(_ value: Double, category: TrackingCategory, volumeUnit: VolumeUnit) -> String {
        switch category {
        case .feed, .pump:
            return "\(decimal(value)) \(volumeUnit.rawValue)"
        case .sleep:
            return "\(decimal(value)) hours"
        case .diaper:
            return "\(Int(value.rounded())) changes"
        case .other:
            return "\(Int(value.rounded()))%"
        }
    }
    static func rangeTitle(_ interval: DateInterval, range: AnalyticsRange) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let last = interval.end.addingTimeInterval(-1)
        if range == .day {
            if calendar.isDateInToday(interval.start) { return "Today" }
            return interval.start.formatted(date: .abbreviated, time: .omitted)
        }
        return "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }
    static func categoryName(_ category: TrackingCategory) -> String { switch category { case .feed:"Feed";case .sleep:"Sleep";case .diaper:"Diaper";case .pump:"Pump";case .other:"Other" } }
    static func featureLabel(_ category: TrackingCategory) -> String { switch category { case .feed:"AVG DAILY BOTTLE";case .sleep:"AVG DAILY SLEEP";case .diaper:"AVG PER DAY";case .pump:"AVG DAILY OUTPUT";case .other:"COMPLETION" } }
    static func volume(_ ml: Double, _ unit: VolumeUnit) -> String { VolumeService.displayString(milliliters: ml, unit: unit) }
    static func volumePoints(_ points: [AnalyticsPoint], unit: VolumeUnit) -> [AnalyticsPoint] {
        points.map {
            AnalyticsPoint(
                id: $0.id,
                value: NSDecimalNumber(decimal: VolumeService.decimalAmount(fromMilliliters: $0.value, unit: unit)).doubleValue
            )
        }
    }
    static func decimal(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    static func percentRatio(_ left: Double,_ right: Double)->String { let total=left+right; guard total>0 else{return "–"}; return "\(Int((left/total*100).rounded())) : \(Int((right/total*100).rounded()))" }
    static func duration(_ seconds: TimeInterval) -> String { let minutes=max(0,Int(seconds/60)); let h=minutes/60; let m=minutes%60; return h>0 ? "\(h)h \(m)m" : "\(m)m" }
}
