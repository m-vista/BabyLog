import Foundation
import Testing
@testable import BabyLog

@MainActor
struct GrowthTrackingTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func measurementRequiresAtLeastOneValidValue() throws {
        #expect(throws: GrowthMeasurementError.missingMeasurement) {
            try GrowthMeasurement.new(
                babyID: "baby",
                timestamp: now,
                weightKilograms: nil,
                heightCentimeters: nil,
                headCircumferenceCentimeters: nil,
                notes: "",
                createdByUserID: "user"
            )
        }

        let value = try measurement(weight: 5.2)
        #expect(value.weightKilograms == 5.2)
        #expect(value.heightCentimeters == nil)
    }

    @Test func formAcceptsAnyCombinationAndPreservesIdentityWhenEditing() throws {
        let original = try measurement(weight: 5.2)
        var form = GrowthFormModel(measurement: original)
        form.weightText = ""
        form.heightText = "61.4"
        let edited = try form.measurement(access: access, existing: original)
        #expect(edited.id == original.id)
        #expect(edited.createdAt == original.createdAt)
        #expect(edited.weightKilograms == nil)
        #expect(edited.heightCentimeters == 61.4)
    }

    @Test func imperialFormStoresCanonicalMetricValues() throws {
        var form = GrowthFormModel(unitSystem: .imperial, now: now)
        form.weightText = "10"
        form.weightOuncesText = "8"
        form.heightText = "24"
        form.headCircumferenceText = "16"

        let value = try form.measurement(access: access, existing: nil, unitSystem: .imperial)
        #expect(abs((value.weightKilograms ?? 0) - 4.76272) < 0.0001)
        #expect(abs((value.heightCentimeters ?? 0) - 60.96) < 0.0001)
        #expect(abs((value.headCircumferenceCentimeters ?? 0) - 40.64) < 0.0001)
    }

    @Test func timelineIncludesGrowthAsOther() throws {
        let value = try measurement(weight: 5.2)
        let entries = TimelineAggregator.makeEntries(
            pumps: [],
            bottles: [],
            nursingSessions: [],
            sleepSessions: [],
            diaperEvents: [],
            checklistEvents: [],
            checklistItemsByID: [:],
            growthMeasurements: [value]
        )
        #expect(entries.count == 1)
        #expect(entries.first?.category == .other)
        #expect(entries.first?.date == now)
    }

    @Test func correctedAgeUsesDueDate() {
        var baby = access.baby
        baby.usesCorrectedDate = true
        baby.dueDate = baby.birthDate.addingTimeInterval(14 * 86_400)
        let chronological = GrowthPercentileService.ageInMonths(
            on: baby.birthDate.addingTimeInterval(30.4375 * 86_400),
            baby: access.baby
        )
        let corrected = GrowthPercentileService.ageInMonths(
            on: baby.birthDate.addingTimeInterval(30.4375 * 86_400),
            baby: baby
        )
        // Growth age is date-based, so a 30.4375-day interval that crosses
        // 30 calendar dates has the expected calendar-day age.
        #expect(abs(chronological - (30 / 30.4375)) < 0.001)
        #expect(corrected < chronological)
    }

    @Test func percentileLinesRequireSpecifiedGender() {
        #expect(GrowthPercentileService.referencePoints(metric: .weight, gender: .preferNotToSay, percentile: 50).isEmpty)
        let boys = GrowthPercentileService.referencePoints(metric: .weight, gender: .boy, percentile: 50)
        #expect(boys.count == 61)
        #expect(abs((boys.first?.value ?? 0) - 3.3464) < 0.001)
    }

    @Test func percentileInterpolatesForEnteredAgeAndValue() {
        let median = GrowthPercentileService.percentile(
            metric: .weight,
            value: 7.934,
            ageMonths: 6,
            gender: .boy
        )
        #expect(median == 50)
        #expect(GrowthPercentileService.percentile(metric: .weight, value: 7.934, ageMonths: 6, gender: .preferNotToSay) == nil)
    }

    @Test func boyWeightPercentileUsesMonthlyWHOReferenceData() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let birthDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 22)))
        let measurementDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 13)))

        var baby = access.baby
        baby.birthDate = birthDate
        baby.gender = .boy
        let age = GrowthPercentileService.ageInMonths(on: measurementDate, baby: baby, calendar: calendar)
        let weightKilograms = 15.625 / 2.204_622_6218

        let percentile = GrowthPercentileService.percentile(
            metric: .weight,
            value: weightKilograms,
            ageMonths: age,
            gender: .boy
        )

        #expect(percentile == 36)
    }

    private var access: BabyAccess {
        let baby = Baby(
            id: "baby",
            name: "Baby",
            birthDate: now.addingTimeInterval(-60 * 86_400),
            createdByUserID: "user",
            createdAt: now,
            updatedAt: now
        )
        let membership = BabyMembership(
            id: "user",
            babyID: "baby",
            userID: "user",
            role: .owner,
            status: .active,
            createdAt: now,
            updatedAt: now
        )
        return BabyAccess(baby: baby, membership: membership)
    }

    private func measurement(weight: Double?) throws -> GrowthMeasurement {
        try GrowthMeasurement.new(
            babyID: "baby",
            timestamp: now,
            weightKilograms: weight,
            heightCentimeters: nil,
            headCircumferenceCentimeters: nil,
            notes: "",
            createdByUserID: "user",
            now: now,
            id: "growth"
        )
    }
}
