import Foundation

enum VolumeUnit: String, Codable, CaseIterable, Sendable {
    case ounces = "oz"
    case milliliters = "mL"
}

enum BottleAutofill: String, Codable, CaseIterable, Sendable {
    case off
    case lastUsed
}

enum GrowthUnitSystem: String, Codable, CaseIterable, Sendable {
    case metric
    case imperial

    var title: String { self == .metric ? "kg, cm" : "lb oz, in" }
}

enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    var title: String { rawValue.capitalized }
}

struct UserPreferences: Codable, Equatable, Sendable {
    var dayStartMinutes: Int
    var volumeUnit: VolumeUnit
    var showRelativeTimes: Bool
    var useCustomDayInTimeline: Bool
    var useCustomDayInCalendar: Bool
    var useCustomDayInAnalytics: Bool
    var rememberPumpDuration: Bool
    var rememberDiaperSize: Bool
    var bottleAutofill: BottleAutofill
    var showPumpRate: Bool
    var separatePostNursingPumps: Bool
    var growthUnitSystem: GrowthUnitSystem
    var appearanceMode: AppearanceMode

    static let defaults = UserPreferences(
        dayStartMinutes: 0,
        volumeUnit: .ounces,
        showRelativeTimes: true,
        useCustomDayInTimeline: true,
        useCustomDayInCalendar: true,
        useCustomDayInAnalytics: true,
        rememberPumpDuration: true,
        rememberDiaperSize: true,
        bottleAutofill: .lastUsed,
        showPumpRate: true,
        separatePostNursingPumps: true,
        growthUnitSystem: .metric,
        appearanceMode: .system
    )

    init(
        dayStartMinutes: Int = 0,
        volumeUnit: VolumeUnit = .ounces,
        showRelativeTimes: Bool = true,
        useCustomDayInTimeline: Bool = true,
        useCustomDayInCalendar: Bool = true,
        useCustomDayInAnalytics: Bool = true,
        rememberPumpDuration: Bool = true,
        rememberDiaperSize: Bool = true,
        bottleAutofill: BottleAutofill = .lastUsed,
        showPumpRate: Bool = true,
        separatePostNursingPumps: Bool = true,
        growthUnitSystem: GrowthUnitSystem = .metric,
        appearanceMode: AppearanceMode = .system
    ) {
        self.dayStartMinutes = (0..<1_440).contains(dayStartMinutes) ? dayStartMinutes : 0
        self.volumeUnit = volumeUnit
        self.showRelativeTimes = showRelativeTimes
        self.useCustomDayInTimeline = useCustomDayInTimeline
        self.useCustomDayInCalendar = useCustomDayInCalendar
        self.useCustomDayInAnalytics = useCustomDayInAnalytics
        self.rememberPumpDuration = rememberPumpDuration
        self.rememberDiaperSize = rememberDiaperSize
        self.bottleAutofill = bottleAutofill
        self.showPumpRate = showPumpRate
        self.separatePostNursingPumps = separatePostNursingPumps
        self.growthUnitSystem = growthUnitSystem
        self.appearanceMode = appearanceMode
    }

    init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            dayStartMinutes: try container.decodeIfPresent(Int.self, forKey: .dayStartMinutes) ?? defaults.dayStartMinutes,
            volumeUnit: try container.decodeIfPresent(VolumeUnit.self, forKey: .volumeUnit) ?? defaults.volumeUnit,
            showRelativeTimes: try container.decodeIfPresent(Bool.self, forKey: .showRelativeTimes) ?? defaults.showRelativeTimes,
            useCustomDayInTimeline: try container.decodeIfPresent(Bool.self, forKey: .useCustomDayInTimeline) ?? defaults.useCustomDayInTimeline,
            useCustomDayInCalendar: try container.decodeIfPresent(Bool.self, forKey: .useCustomDayInCalendar) ?? defaults.useCustomDayInCalendar,
            useCustomDayInAnalytics: try container.decodeIfPresent(Bool.self, forKey: .useCustomDayInAnalytics) ?? defaults.useCustomDayInAnalytics,
            rememberPumpDuration: try container.decodeIfPresent(Bool.self, forKey: .rememberPumpDuration) ?? defaults.rememberPumpDuration,
            rememberDiaperSize: try container.decodeIfPresent(Bool.self, forKey: .rememberDiaperSize) ?? defaults.rememberDiaperSize,
            bottleAutofill: try container.decodeIfPresent(BottleAutofill.self, forKey: .bottleAutofill) ?? defaults.bottleAutofill,
            showPumpRate: try container.decodeIfPresent(Bool.self, forKey: .showPumpRate) ?? defaults.showPumpRate,
            separatePostNursingPumps: try container.decodeIfPresent(Bool.self, forKey: .separatePostNursingPumps) ?? defaults.separatePostNursingPumps,
            growthUnitSystem: try container.decodeIfPresent(GrowthUnitSystem.self, forKey: .growthUnitSystem) ?? defaults.growthUnitSystem,
            appearanceMode: try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? defaults.appearanceMode
        )
    }
}
