import Foundation
import Darwin

enum GrowthMetric: String, CaseIterable, Identifiable, Sendable {
    case weight
    case height
    case headCircumference

    var id: String { rawValue }
    var title: String {
        switch self {
        case .weight: "Weight"
        case .height: "Height"
        case .headCircumference: "Head"
        }
    }
    var unit: String { self == .weight ? "kg" : "cm" }

    func value(in measurement: GrowthMeasurement) -> Double? {
        switch self {
        case .weight: measurement.weightKilograms
        case .height: measurement.heightCentimeters
        case .headCircumference: measurement.headCircumferenceCentimeters
        }
    }
}

struct GrowthChartPoint: Identifiable, Sendable {
    let id: String
    let ageMonths: Double
    let value: Double
    let percentile: Int?
}

enum GrowthPercentileService {
    struct LMS {
        let age: Double
        let l: Double
        let m: Double
        let s: Double
    }

    static let percentiles = [3, 15, 50, 85, 97]

    static func ageInMonths(on date: Date, baby: Baby, calendar: Calendar = .autoupdatingCurrent) -> Double {
        let reference = baby.usesCorrectedDate == true ? (baby.dueDate ?? baby.birthDate) : baby.birthDate
        let referenceDay = calendar.startOfDay(for: reference)
        let measurementDay = calendar.startOfDay(for: date)
        return max(0, measurementDay.timeIntervalSince(referenceDay) / (30.4375 * 86_400))
    }

    static func measurementPoints(_ measurements: [GrowthMeasurement], metric: GrowthMetric, baby: Baby) -> [GrowthChartPoint] {
        measurements.compactMap { measurement in
            guard let value = metric.value(in: measurement) else { return nil }
            return GrowthChartPoint(
                id: measurement.id,
                ageMonths: ageInMonths(on: measurement.timestamp, baby: baby),
                value: value,
                percentile: nil
            )
        }
        .sorted { $0.ageMonths < $1.ageMonths }
    }

    static func referencePoints(metric: GrowthMetric, gender: BabyGender, percentile: Int) -> [GrowthChartPoint] {
        guard gender != .preferNotToSay, let z = zScores[percentile] else { return [] }
        return anchors(metric: metric, gender: gender).map { value in
            GrowthChartPoint(
                id: "\(metric.rawValue)-\(percentile)-\(value.age)",
                ageMonths: value.age,
                value: percentileValue(lms: value, z: z),
                percentile: percentile
            )
        }
    }

    static func percentile(metric: GrowthMetric, value: Double, ageMonths: Double, gender: BabyGender) -> Int? {
        guard gender != .preferNotToSay,
              let lms = interpolatedLMS(metric: metric, gender: gender, ageMonths: ageMonths),
              value > 0 else { return nil }
        let z: Double
        if abs(lms.l) < 0.000_001 {
            z = log(value / lms.m) / lms.s
        } else {
            z = (pow(value / lms.m, lms.l) - 1) / (lms.l * lms.s)
        }
        let probability = 0.5 * (1 + erf(z / sqrt(2)))
        return min(99, max(1, Int((probability * 100).rounded())))
    }

    /// e.g. "Weight 62nd · Height 40th · Head 55th percentile"; nil without a sex-specific standard.
    static func percentileSummary(_ measurement: GrowthMeasurement, baby: Baby) -> String? {
        guard let gender = baby.gender, gender != .preferNotToSay else { return nil }
        let ageMonths = ageInMonths(on: measurement.timestamp, baby: baby)
        let parts = GrowthMetric.allCases.compactMap { metric -> String? in
            guard let value = metric.value(in: measurement),
                  let rank = percentile(metric: metric, value: value, ageMonths: ageMonths, gender: gender)
            else { return nil }
            return "\(metric.title) \(rank.ordinal)"
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ") + " percentile"
    }

    /// Measurement points whose `value` is the WHO percentile (1–99) at that age.
    static func percentilePoints(_ measurements: [GrowthMeasurement], metric: GrowthMetric, baby: Baby) -> [GrowthChartPoint] {
        guard let gender = baby.gender, gender != .preferNotToSay else { return [] }
        return measurementPoints(measurements, metric: metric, baby: baby).compactMap { point in
            guard let rank = percentile(metric: metric, value: point.value, ageMonths: point.ageMonths, gender: gender) else { return nil }
            return GrowthChartPoint(id: point.id, ageMonths: point.ageMonths, value: Double(rank), percentile: rank)
        }
    }

    /// Y range hugging the measured values: up to the largest value + 25% headroom.
    static func valueDomain(for values: [Double], headroom: Double = 0.25) -> ClosedRange<Double>? {
        guard let low = values.min(), let high = values.max(), high > 0 else { return nil }
        let upper = high * (1 + headroom)
        let lower = max(0, low * (1 - headroom))
        return lower < upper ? lower...upper : 0...upper
    }

    private static func percentileValue(lms: LMS, z: Double) -> Double {
        if abs(lms.l) < 0.000_001 {
            return lms.m * exp(lms.s * z)
        }
        return lms.m * pow(1 + lms.l * lms.s * z, 1 / lms.l)
    }

    private static func interpolatedLMS(metric: GrowthMetric, gender: BabyGender, ageMonths: Double) -> LMS? {
        let values = anchors(metric: metric, gender: gender)
        guard let first = values.first, let last = values.last else { return nil }
        let age = min(last.age, max(first.age, ageMonths))
        guard let upperIndex = values.firstIndex(where: { $0.age >= age }) else { return last }
        guard upperIndex > 0 else { return first }
        let lower = values[upperIndex - 1]
        let upper = values[upperIndex]
        let fraction = (age - lower.age) / max(upper.age - lower.age, 0.000_001)
        return LMS(
            age: age,
            l: lower.l + (upper.l - lower.l) * fraction,
            m: lower.m + (upper.m - lower.m) * fraction,
            s: lower.s + (upper.s - lower.s) * fraction
        )
    }

    private static let zScores = [3: -1.88079, 15: -1.03643, 50: 0, 85: 1.03643, 97: 1.88079]

    private static func anchors(metric: GrowthMetric, gender: BabyGender) -> [LMS] {
        switch (metric, gender) {
        case (.weight, .girl): girlWeight
        case (.weight, .boy): boyWeight
        case (.height, .girl): girlHeight
        case (.height, .boy): boyHeight
        case (.headCircumference, .girl): girlHead
        case (.headCircumference, .boy): boyHead
        case (_, .preferNotToSay): []
        }
    }

    // WHO Child Growth Standards monthly weight-for-age LMS values, birth through age 5.
    // The remaining metrics are sampled at chart anchors and interpolated between them.
    private static let girlWeight = make([
        (0,0.3809,3.2322,0.14171),(1,0.1714,4.1873,0.13724),(2,0.0962,5.1282,0.13000),
        (3,0.0402,5.8458,0.12619),(4,-0.0050,6.4237,0.12402),(5,-0.0430,6.8985,0.12274),
        (6,-0.0756,7.2970,0.12204),(7,-0.1039,7.6422,0.12178),(8,-0.1288,7.9487,0.12181),
        (9,-0.1507,8.2254,0.12199),(10,-0.1700,8.4800,0.12223),(11,-0.1872,8.7192,0.12247),
        (12,-0.2024,8.9481,0.12268),(13,-0.2158,9.1699,0.12283),(14,-0.2278,9.3870,0.12294),
        (15,-0.2384,9.6008,0.12299),(16,-0.2478,9.8124,0.12303),(17,-0.2562,10.0226,0.12306),
        (18,-0.2637,10.2315,0.12309),(19,-0.2703,10.4393,0.12315),(20,-0.2762,10.6464,0.12323),
        (21,-0.2815,10.8534,0.12335),(22,-0.2862,11.0608,0.12350),(23,-0.2903,11.2688,0.12369),
        (24,-0.2941,11.4775,0.12390),(25,-0.2975,11.6864,0.12414),(26,-0.3005,11.8947,0.12441),
        (27,-0.3032,12.1015,0.12472),(28,-0.3057,12.3059,0.12506),(29,-0.3080,12.5073,0.12545),
        (30,-0.3101,12.7055,0.12587),(31,-0.3120,12.9006,0.12633),(32,-0.3138,13.0930,0.12683),
        (33,-0.3155,13.2837,0.12737),(34,-0.3171,13.4731,0.12794),(35,-0.3186,13.6618,0.12855),
        (36,-0.3201,13.8503,0.12919),(37,-0.3216,14.0385,0.12988),(38,-0.3230,14.2265,0.13059),
        (39,-0.3243,14.4140,0.13135),(40,-0.3257,14.6010,0.13213),(41,-0.3270,14.7873,0.13293),
        (42,-0.3283,14.9727,0.13376),(43,-0.3296,15.1573,0.13460),(44,-0.3309,15.3410,0.13545),
        (45,-0.3322,15.5240,0.13630),(46,-0.3335,15.7064,0.13716),(47,-0.3348,15.8882,0.13800),
        (48,-0.3361,16.0697,0.13884),(49,-0.3374,16.2511,0.13968),(50,-0.3387,16.4322,0.14051),
        (51,-0.3400,16.6133,0.14132),(52,-0.3414,16.7942,0.14213),(53,-0.3427,16.9748,0.14293),
        (54,-0.3440,17.1551,0.14371),(55,-0.3453,17.3347,0.14448),(56,-0.3466,17.5136,0.14525),
        (57,-0.3479,17.6916,0.14600),(58,-0.3492,17.8686,0.14675),(59,-0.3505,18.0445,0.14748),
        (60,-0.3518,18.2193,0.14821)
    ])
    private static let boyWeight = make([
        (0,0.3487,3.3464,0.14602),(1,0.2297,4.4709,0.13395),(2,0.1970,5.5675,0.12385),
        (3,0.1738,6.3762,0.11727),(4,0.1553,7.0023,0.11316),(5,0.1395,7.5105,0.11080),
        (6,0.1257,7.9340,0.10958),(7,0.1134,8.2970,0.10902),(8,0.1021,8.6151,0.10882),
        (9,0.0917,8.9014,0.10881),(10,0.0820,9.1649,0.10891),(11,0.0730,9.4122,0.10906),
        (12,0.0644,9.6479,0.10925),(13,0.0563,9.8749,0.10949),(14,0.0487,10.0953,0.10976),
        (15,0.0413,10.3108,0.11007),(16,0.0343,10.5228,0.11041),(17,0.0275,10.7319,0.11079),
        (18,0.0211,10.9385,0.11119),(19,0.0148,11.1430,0.11164),(20,0.0087,11.3462,0.11211),
        (21,0.0029,11.5486,0.11261),(22,-0.0028,11.7504,0.11314),(23,-0.0083,11.9514,0.11369),
        (24,-0.0137,12.1515,0.11426),(25,-0.0189,12.3502,0.11485),(26,-0.0240,12.5466,0.11544),
        (27,-0.0289,12.7401,0.11604),(28,-0.0337,12.9303,0.11664),(29,-0.0385,13.1169,0.11723),
        (30,-0.0431,13.3000,0.11781),(31,-0.0476,13.4798,0.11839),(32,-0.0520,13.6567,0.11896),
        (33,-0.0564,13.8309,0.11953),(34,-0.0606,14.0031,0.12008),(35,-0.0648,14.1736,0.12062),
        (36,-0.0689,14.3429,0.12116),(37,-0.0729,14.5113,0.12168),(38,-0.0769,14.6791,0.12220),
        (39,-0.0808,14.8466,0.12271),(40,-0.0846,15.0140,0.12322),(41,-0.0883,15.1813,0.12373),
        (42,-0.0920,15.3486,0.12425),(43,-0.0957,15.5158,0.12478),(44,-0.0993,15.6828,0.12531),
        (45,-0.1028,15.8497,0.12586),(46,-0.1063,16.0163,0.12643),(47,-0.1097,16.1827,0.12700),
        (48,-0.1131,16.3489,0.12759),(49,-0.1165,16.5150,0.12819),(50,-0.1198,16.6811,0.12880),
        (51,-0.1230,16.8471,0.12943),(52,-0.1262,17.0132,0.13005),(53,-0.1294,17.1792,0.13069),
        (54,-0.1325,17.3452,0.13133),(55,-0.1356,17.5111,0.13197),(56,-0.1387,17.6768,0.13261),
        (57,-0.1417,17.8422,0.13325),(58,-0.1447,18.0073,0.13389),(59,-0.1477,18.1722,0.13453),
        (60,-0.1506,18.3366,0.13517)
    ])
    private static let girlHeight = make([
        (0,1,49.14770,0.03790),(3,1,59.77730,0.03520),(6,1,65.75100,0.03448),(9,1,70.14630,0.03444),(12,1,74.00490,0.03479),(18,1,80.71210,0.03598),(24,1,86.40080,0.03733),(36,1,95.05720,0.04007),(48,1,102.73120,0.04193),(60,1,109.41890,0.04346)
    ])
    private static let boyHeight = make([
        (0,1,49.88420,0.03795),(3,1,61.40130,0.03329),(6,1,67.64350,0.03165),(9,1,71.97140,0.03117),(12,1,75.73910,0.03137),(18,1,82.26280,0.03279),(24,1,87.80180,0.03479),(36,1,96.08890,0.03858),(48,1,103.32730,0.04059),(60,1,109.95930,0.04214)
    ])
    private static let girlHead = make([
        (0,1,33.87870,0.03496),(3,1,39.52100,0.03140),(6,1,42.20790,0.03087),(9,1,43.83090,0.03053),(12,1,44.89400,0.03027),(18,1,46.24310,0.02987),(24,1,47.17990,0.02958),(36,1,48.51060,0.02912),(48,1,49.33210,0.02878),(60,1,49.92250,0.02850)
    ])
    private static let boyHead = make([
        (0,1,34.46180,0.03686),(3,1,40.50080,0.02918),(6,1,43.33930,0.02817),(9,1,45.00070,0.02792),(12,1,46.06370,0.02789),(18,1,47.37180,0.02800),(24,1,48.24940,0.02821),(36,1,49.46190,0.02871),(48,1,50.21150,0.02912),(60,1,50.73720,0.02945)
    ])

    private static func make(_ values: [(Double, Double, Double, Double)]) -> [LMS] {
        values.map { LMS(age: $0.0, l: $0.1, m: $0.2, s: $0.3) }
    }
}

extension Int {
    /// English ordinal, e.g. 1st, 22nd, 13th.
    var ordinal: String {
        let remainder100 = self % 100
        let suffix: String
        if (11...13).contains(remainder100) { suffix = "th" }
        else {
            switch self % 10 { case 1: suffix = "st"; case 2: suffix = "nd"; case 3: suffix = "rd"; default: suffix = "th" }
        }
        return "\(self)\(suffix)"
    }
}
