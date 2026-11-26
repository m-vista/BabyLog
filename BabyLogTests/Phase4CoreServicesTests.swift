import Foundation
import Testing
@testable import BabyLog

struct Phase4CoreServicesTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test func midnightTrackingDayBoundary() {
        let calendar = calendar()
        let before = date(2026, 9, 29, 23, 59)
        let atBoundary = date(2026, 9, 30, 0, 0)

        let beforeInterval = TrackingDayService.interval(containing: before, calendar: calendar)
        let boundaryInterval = TrackingDayService.interval(containing: atBoundary, calendar: calendar)

        #expect(beforeInterval.start == date(2026, 9, 29, 0, 0))
        #expect(boundaryInterval.start == date(2026, 9, 30, 0, 0))
    }

    @Test func fiveAMTrackingDayBoundaryAndSurfaceToggles() {
        let calendar = calendar()
        var preferences = UserPreferences(dayStartMinutes: 300)
        let before = date(2026, 9, 30, 4, 59)
        let atBoundary = date(2026, 9, 30, 5, 0)

        #expect(TrackingDayService.interval(
            containing: before,
            surface: .timeline,
            preferences: preferences,
            calendar: calendar
        ).start == date(2026, 9, 29, 5, 0))
        #expect(TrackingDayService.interval(
            containing: atBoundary,
            surface: .calendar,
            preferences: preferences,
            calendar: calendar
        ).start == atBoundary)

        preferences.useCustomDayInAnalytics = false
        #expect(TrackingDayService.interval(
            containing: before,
            surface: .analytics,
            preferences: preferences,
            calendar: calendar
        ).start == date(2026, 9, 30, 0, 0))
    }

    @Test func trackingDayUsesCalendarTimeZoneAndDSTLength() {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.locale = Locale(identifier: "en_US")
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let noonAfterSpringChange = losAngeles.date(from: DateComponents(
            year: 2026, month: 3, day: 8, hour: 12
        ))!

        let interval = TrackingDayService.interval(
            containing: noonAfterSpringChange,
            calendar: losAngeles
        )

        #expect(interval.duration == 23 * 3_600)
    }

    @Test func everyHundredthOunceRoundTrips() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        for hundredths in 0...12_800 {
            let input = Decimal(hundredths) / 100
            let milliliters = try VolumeService.milliliters(from: input, unit: .ounces)
            let displayed = VolumeService.displayString(
                milliliters: milliliters,
                unit: .ounces,
                locale: locale
            )
            #expect(Decimal(string: displayed) == input)
        }
    }

    @Test func everyTenthMilliliterDisplaysUnchanged() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        for tenths in 0...40_000 {
            let input = Decimal(tenths) / 10
            let milliliters = try VolumeService.milliliters(from: input, unit: .milliliters)
            let displayed = VolumeService.displayString(
                milliliters: milliliters,
                unit: .milliliters,
                locale: locale
            )
            #expect(Decimal(string: displayed) == input)
        }
    }

    @Test func volumeInputPrecisionAndNegativeValidation() throws {
        #expect(try VolumeService.parse("1.23", unit: .ounces) == Decimal(string: "1.23"))
        #expect(try VolumeService.parse("1.2", unit: .milliliters) == Decimal(string: "1.2"))
        #expect(throws: VolumeServiceError.tooManyFractionDigits) {
            try VolumeService.parse("1.234", unit: .ounces)
        }
        #expect(throws: VolumeServiceError.tooManyFractionDigits) {
            try VolumeService.parse("1.23", unit: .milliliters)
        }
        #expect(throws: VolumeServiceError.negativeAmount) {
            try VolumeService.parse("-0.1", unit: .milliliters)
        }
    }

    @Test func untouchedAmountRemainsBitIdentical() throws {
        let stored = Double(bitPattern: 0x400921fb54442d18)
        let saved = try VolumeService.storedValue(
            existingMilliliters: stored,
            isDirty: false,
            input: "999",
            unit: .ounces
        )

        #expect(saved.bitPattern == stored.bitPattern)
    }

    @Test(arguments: [
        (Decimal(string: "1.10"), Decimal(string: "2.20"), nil, AmountField.total),
        (Decimal(string: "1.10"), nil, Decimal(string: "3.30"), AmountField.right),
        (nil, Decimal(string: "2.20"), Decimal(string: "3.30"), AmountField.left),
    ])
    func allAmountInputPairs(
        left: Decimal?,
        right: Decimal?,
        total: Decimal?,
        expectedField: AmountField
    ) throws {
        let result = try AmountCalculator.calculate(
            left: left,
            right: right,
            total: total,
            unit: .milliliters
        )

        #expect(result.leftMilliliters == 1.1)
        #expect(result.rightMilliliters == 2.2)
        #expect(result.totalMilliliters == 3.3)
        #expect(result.calculatedField == expectedField)
    }

    @Test func calculatedFieldUsesDecimalInputDomainBeforeConversion() throws {
        let expected = try VolumeService.milliliters(
            from: Decimal(string: "0.20")!,
            unit: .ounces
        )
        let result = try AmountCalculator.calculate(
            left: Decimal(string: "0.10"),
            right: nil,
            total: Decimal(string: "0.30"),
            unit: .ounces
        )

        #expect(result.rightMilliliters.bitPattern == expected.bitPattern)
    }

    @Test func calculatedFieldRejectsNegativeResult() {
        #expect(throws: AmountCalculatorError.negativeResult) {
            try AmountCalculator.calculate(
                left: Decimal(string: "2"),
                right: nil,
                total: Decimal(string: "1"),
                unit: .ounces
            )
        }
    }

    @Test func calculatedFieldClampsNearZero() throws {
        let result = try AmountCalculator.calculate(
            left: Decimal(string: "1.0000000005"),
            right: nil,
            total: Decimal(string: "1"),
            unit: .milliliters
        )

        #expect(result.rightMilliliters == 0)
        #expect(result.rightMilliliters.bitPattern == 0.0.bitPattern)
    }

    @Test(arguments: [
        (18, 59, SleepClassification.nap),
        (19, 0, SleepClassification.night),
        (6, 59, SleepClassification.night),
        (7, 0, SleepClassification.nap),
    ])
    func defaultSleepBoundary(hour: Int, minute: Int, expected: SleepClassification) {
        #expect(SleepClassifier.classify(
            startTime: date(2026, 9, 30, hour, minute),
            calendar: calendar()
        ) == expected)
    }

    @Test func customNonWrappingNightWindow() {
        #expect(SleepClassifier.classify(
            startTime: date(2026, 9, 30, 13, 0),
            nightStartMinutes: 12 * 60,
            nightEndMinutes: 14 * 60,
            calendar: calendar()
        ) == .night)
        #expect(SleepClassifier.classify(
            startTime: date(2026, 9, 30, 15, 0),
            nightStartMinutes: 12 * 60,
            nightEndMinutes: 14 * 60,
            calendar: calendar()
        ) == .nap)
    }

    @Test func nightWindowWrapsMidnight() {
        #expect(SleepClassifier.classify(
            startTime: date(2026, 9, 30, 23, 0),
            nightStartMinutes: 22 * 60,
            nightEndMinutes: 5 * 60,
            calendar: calendar()
        ) == .night)
        #expect(SleepClassifier.classify(
            startTime: date(2026, 9, 30, 4, 59),
            nightStartMinutes: 22 * 60,
            nightEndMinutes: 5 * 60,
            calendar: calendar()
        ) == .night)
        #expect(SleepClassifier.classify(
            startTime: date(2026, 9, 30, 5, 0),
            nightStartMinutes: 22 * 60,
            nightEndMinutes: 5 * 60,
            calendar: calendar()
        ) == .nap)
    }

    @Test func relativeTimeBasics() {
        let now = date(2026, 9, 30, 12, 0)
        #expect(RelativeTimeService.string(for: now.addingTimeInterval(-59), relativeTo: now) == "Now")
        #expect(RelativeTimeService.string(for: now.addingTimeInterval(-20 * 60), relativeTo: now) == "20m ago")
        #expect(RelativeTimeService.string(for: now.addingTimeInterval(-(84 * 60)), relativeTo: now) == "1h 24m ago")
        #expect(RelativeTimeService.string(for: now.addingTimeInterval(-(2 * 3_600)), relativeTo: now) == "2h ago")
    }

    @Test func formattersRespectLocaleTimeConventionAndTimeZone() {
        let value = date(2026, 9, 30, 14, 47)
        let twelveHour = AppFormatters.time(
            locale: Locale(identifier: "en_US"),
            timeZone: utc
        ).string(from: value)
        let twentyFourHour = AppFormatters.time(
            locale: Locale(identifier: "en_GB"),
            timeZone: utc
        ).string(from: value)

        #expect(twelveHour.contains("2:47"))
        #expect(twelveHour.uppercased().contains("PM"))
        #expect(twentyFourHour.contains("14:47"))
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = utc
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        calendar().date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}

struct Phase4PreferencesTests {
    @Test func preferenceDefaults() {
        let defaults = UserPreferences.defaults

        #expect(defaults.dayStartMinutes == 0)
        #expect(defaults.volumeUnit == .ounces)
        #expect(defaults.showRelativeTimes)
        #expect(defaults.useCustomDayInTimeline)
        #expect(defaults.useCustomDayInCalendar)
        #expect(defaults.useCustomDayInAnalytics)
        #expect(defaults.rememberPumpDuration)
        #expect(defaults.rememberDiaperSize)
        #expect(defaults.bottleAutofill == .lastUsed)
        #expect(defaults.showPumpRate)
        #expect(defaults.separatePostNursingPumps)
    }

    @Test func decodingMissingPreferenceFieldsUsesDefaults() throws {
        let decoded = try UserRepository.decodePreferences([
            "dayStartMinutes": 300,
            "volumeUnit": "mL",
            "showRelativeTimes": false,
        ])

        #expect(decoded.dayStartMinutes == 300)
        #expect(decoded.volumeUnit == .milliliters)
        #expect(!decoded.showRelativeTimes)
        #expect(decoded.rememberPumpDuration == UserPreferences.defaults.rememberPumpDuration)
    }

    @Test func preferenceUpdateTouchesNoProfileFields() throws {
        let fields = try UserRepository.preferenceUpdateData(
            .defaults,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(Set(fields.keys) == ["preferences", "updatedAt"])
        #expect(fields["displayName"] == nil)
        #expect(fields["email"] == nil)
        #expect(fields["createdAt"] == nil)
    }

    @MainActor
    @Test func observableStoreLoadsAndUpdatesThroughRepository() async throws {
        let initial = UserPreferences(dayStartMinutes: 300, volumeUnit: .milliliters)
        let repository = FakePreferencesRepository(value: initial)
        let store = UserPreferencesStore(repository: repository)

        try await store.load(userID: "user-a")
        #expect(store.values == initial)
        #expect(store.loadedUserID == "user-a")

        var updated = initial
        updated.showRelativeTimes = false
        try await store.update(updated, userID: "user-a")

        #expect(store.values == updated)
        #expect(await repository.savedValue() == updated)
        #expect(await repository.savedUserID() == "user-a")
    }
}

@MainActor
private final class FakePreferencesRepository: UserPreferencesRepository {
    private var value: UserPreferences
    private var updatedUserID: String?

    init(value: UserPreferences) {
        self.value = value
    }

    func loadPreferences(userID: String) async throws -> UserPreferences {
        value
    }

    func updatePreferences(_ preferences: UserPreferences, userID: String) async throws {
        value = preferences
        updatedUserID = userID
    }

    func savedValue() -> UserPreferences {
        value
    }

    func savedUserID() -> String? {
        updatedUserID
    }
}
