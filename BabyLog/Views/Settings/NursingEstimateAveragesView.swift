import SwiftUI

struct NursingEstimateAveragesView: View {
    @Environment(AppEnvironment.self) private var environment
    let access: BabyAccess
    @State private var averages: NursingEstimateAverages?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let averages {
                    Text("Based on your last \(averages.sampleCount) clean pump\(averages.sampleCount == 1 ? "" : "s") (post-nursing pumps excluded). Nursing estimates use these production rates.")
                        .font(AppFont.secondary)
                        .foregroundStyle(BabyLogTheme.mutedText)
                    statsCard(title: "TOTAL", stats: averages.total)
                    statsCard(title: "LEFT", stats: averages.left)
                    statsCard(title: "RIGHT", stats: averages.right)
                } else {
                    Text(errorMessage ?? "Not enough clean pumps yet. Log at least two pumps to see averages.")
                        .font(AppFont.secondary)
                        .foregroundStyle(BabyLogTheme.mutedText)
                }
            }
            .padding(16)
        }
        .background(BabyLogTheme.cream)
        .navigationTitle("Current Averages")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func statsCard(title: String, stats: NursingRateStats?) -> some View {
        SettingsGroup(title: title) {
            if let stats {
                row("Average", stats.average)
                row("Lowest", stats.lowest)
                row("Highest", stats.highest, showsDivider: false)
            } else {
                Text("No side-specific amounts logged")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            }
        }
    }

    private func row(_ label: String, _ mlPerHour: Double, showsDivider: Bool = true) -> some View {
        let unit = environment.preferences.values.volumeUnit
        return SettingsValueRow(
            title: label,
            value: "\(VolumeService.displayString(milliliters: mlPerHour, unit: unit)) \(unit.rawValue)/hr",
            showsChevron: false,
            showsDivider: showsDivider
        )
    }

    @MainActor private func load() async {
        defer { isLoading = false }
        do {
            let sessions = try await environment.pumpRepository.fetchRecent(babyID: access.baby.id, limit: 40)
            averages = NursingEstimateService.currentAverages(pumpSessions: sessions)
        } catch {
            errorMessage = "Averages are unavailable right now."
        }
    }
}
