import Charts
import SwiftUI

struct GrowthAnalyticsSection: View {
    let measurements: [GrowthMeasurement]
    let baby: Baby
    let unitSystem: GrowthUnitSystem
    @State private var metric: GrowthMetric = .weight
    @State private var showsHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GROWTH")
                .font(AppFont.eyebrow)
                .tracking(1.2)
                .foregroundStyle(BabyLogTheme.mutedText)

            Picker("Growth measurement", selection: $metric) {
                ForEach(GrowthMetric.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Button {
                showsHistory = true
            } label: {
                Label("View all measurements", systemImage: "list.bullet")
                    .font(AppFont.primaryRow.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(measurements.isEmpty)

            if points.isEmpty {
                Text("No \(metric.title.lowercased()) measurements yet.")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                chart
                if !percentilePoints.isEmpty {
                    Text("\(metric.title.uppercased()) PERCENTILE BY AGE")
                        .font(AppFont.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(BabyLogTheme.mutedText)
                        .padding(.top, 6)
                    percentileChart
                }
            }

            if baby.gender == nil || baby.gender == .preferNotToSay {
                Label("Choose Boy or Girl in the baby profile to show accurate WHO percentile lines.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(BabyLogTheme.mutedText)
            } else {
                Text("WHO Child Growth Standards, birth to 5 years. Percentile lines: 3rd, 15th, 50th, 85th and 97th.")
                    .font(.caption)
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
            if baby.usesCorrectedDate == true {
                Text("Age is corrected using the saved due date.")
                    .font(.caption)
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
        }
        .padding(16)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: BabyLogTheme.shadowColor, radius: 10, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .sheet(isPresented: $showsHistory) {
            GrowthHistoryView(measurements: measurements, baby: baby, unitSystem: unitSystem)
        }
    }

    private var points: [GrowthChartPoint] {
        GrowthPercentileService.measurementPoints(measurements, metric: metric, baby: baby)
    }

    private var chart: some View {
        Chart {
            if let gender = baby.gender, gender != .preferNotToSay {
                ForEach(GrowthPercentileService.percentiles, id: \.self) { percentile in
                    ForEach(GrowthPercentileService.referencePoints(metric: metric, gender: gender, percentile: percentile)) { point in
                        LineMark(
                            x: .value("Age in months", point.ageMonths),
                            y: .value(metric.title, displayValue(point.value)),
                            series: .value("Percentile", percentile)
                        )
                        .foregroundStyle(BabyLogTheme.muted.opacity(percentile == 50 ? 0.65 : 0.3))
                        .lineStyle(StrokeStyle(lineWidth: percentile == 50 ? 1.5 : 1, dash: [4, 3]))
                    }
                }
            }
            ForEach(points) { point in
                LineMark(x: .value("Age in months", point.ageMonths), y: .value(metric.title, displayValue(point.value)))
                    .foregroundStyle(BabyLogTheme.brown700)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Age in months", point.ageMonths), y: .value(metric.title, displayValue(point.value)))
                    .foregroundStyle(BabyLogTheme.brown700)
                    .symbolSize(42)
            }
        }
        .chartXAxisLabel("Age (months)")
        .chartYAxisLabel(displayUnit)
        .chartXScale(domain: 0...chartMaximumAgeMonths)
        .chartYScale(domain: valueDomain)
        .chartPlotStyle { $0.clipped() }
        .frame(height: 250)
        .accessibilityLabel("\(metric.title) growth chart")
    }

    private var percentilePoints: [GrowthChartPoint] {
        GrowthPercentileService.percentilePoints(measurements, metric: metric, baby: baby)
    }

    private var percentileChart: some View {
        Chart {
            ForEach(GrowthPercentileService.percentiles, id: \.self) { percentile in
                RuleMark(y: .value("Reference percentile", percentile))
                    .foregroundStyle(BabyLogTheme.muted.opacity(percentile == 50 ? 0.65 : 0.3))
                    .lineStyle(StrokeStyle(lineWidth: percentile == 50 ? 1.5 : 1, dash: [4, 3]))
            }
            ForEach(percentilePoints) { point in
                LineMark(x: .value("Age in months", point.ageMonths), y: .value("Percentile", point.value))
                    .foregroundStyle(BabyLogTheme.brown700)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Age in months", point.ageMonths), y: .value("Percentile", point.value))
                    .foregroundStyle(BabyLogTheme.brown700)
                    .symbolSize(42)
            }
        }
        .chartXAxisLabel("Age (months)")
        .chartYAxisLabel("Percentile")
        .chartXScale(domain: 0...chartMaximumAgeMonths)
        .chartYScale(domain: 0...100)
        .chartYAxis { AxisMarks(values: GrowthPercentileService.percentiles) }
        .frame(height: 200)
        .accessibilityLabel("\(metric.title) percentile by age chart")
    }

    private var valueDomain: ClosedRange<Double> {
        let range = GrowthPercentileService.valueDomain(for: points.map(\.value)) ?? 0...1
        return displayValue(range.lowerBound)...displayValue(range.upperBound)
    }

    private var chartMaximumAgeMonths: Double {
        max(1, GrowthPercentileService.ageInMonths(on: .now, baby: baby) * 1.25)
    }

    private var displayUnit: String {
        if unitSystem == .metric { return metric.unit }
        return metric == .weight ? "lb" : "in"
    }

    private func displayValue(_ value: Double) -> Double {
        guard unitSystem == .imperial else { return value }
        return metric == .weight ? value * 2.204_622_6218 : value / 2.54
    }
}

private struct GrowthHistoryView: View {
    let measurements: [GrowthMeasurement]
    let baby: Baby
    let unitSystem: GrowthUnitSystem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(measurements.sorted { $0.timestamp > $1.timestamp }) { measurement in
                VStack(alignment: .leading, spacing: 5) {
                    Text(measurement.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(AppFont.primaryRow.bold())
                    Text(GrowthFormat.summary(measurement, unitSystem: unitSystem))
                        .font(AppFont.primaryRow)
                        .foregroundStyle(BabyLogTheme.ink)
                    if let percentiles = GrowthPercentileService.percentileSummary(measurement, baby: baby) {
                        Text(percentiles)
                            .font(AppFont.secondary)
                            .foregroundStyle(BabyLogTheme.ink)
                    }
                    Text(ageText(for: measurement.timestamp))
                        .font(AppFont.secondary)
                        .foregroundStyle(BabyLogTheme.mutedText)
                    if !measurement.notes.isEmpty {
                        Text(measurement.notes)
                            .font(AppFont.secondary)
                            .foregroundStyle(BabyLogTheme.mutedText)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Growth History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func ageText(for date: Date) -> String {
        let months = GrowthPercentileService.ageInMonths(on: date, baby: baby)
        return "Age \(months.formatted(.number.precision(.fractionLength(0...1)))) months"
    }
}
