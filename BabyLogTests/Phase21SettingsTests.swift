import Foundation
import Testing
@testable import BabyLog

@Suite("Phase 21 Settings")
struct Phase21SettingsTests {
    @Test("Day start converts between minutes and a local time")
    func dayStartConversion() {
        for minutes in [0, 300, 720, 1_439] {
            #expect(SettingsTime.minutes(SettingsTime.date(minutes)) == minutes)
        }
    }

    @Test("Preference persistence retains every Phase 21 control")
    func preferenceRoundTrip() throws {
        let original = UserPreferences(
            dayStartMinutes: 300, volumeUnit: .milliliters, showRelativeTimes: false,
            useCustomDayInTimeline: false, useCustomDayInCalendar: true,
            useCustomDayInAnalytics: false, rememberPumpDuration: false,
            rememberDiaperSize: false, bottleAutofill: .off,
            showPumpRate: false, separatePostNursingPumps: false
        )
        #expect(try UserRepository.decodePreferences(UserRepository.encodePreferences(original)) == original)
    }

    @Test("Invalid day-start values safely use midnight")
    func invalidDayStart() {
        #expect(UserPreferences(dayStartMinutes: -1).dayStartMinutes == 0)
        #expect(UserPreferences(dayStartMinutes: 1_440).dayStartMinutes == 0)
    }
}
