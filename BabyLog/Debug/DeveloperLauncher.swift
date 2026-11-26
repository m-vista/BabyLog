#if DEBUG
import SwiftUI

enum DeveloperLoggerDestination: String, CaseIterable, Identifiable {
    static let launchArgument = "-Phase6DebugLauncher"

    case pump
    case bottle
    case nursing
    case sleep
    case diaper
    case checklistConfirmation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pump: "Pump"
        case .bottle: "Bottle"
        case .nursing: "Nursing"
        case .sleep: "Sleep"
        case .diaper: "Diaper"
        case .checklistConfirmation: "Checklist confirmation"
        }
    }

    var systemImage: String {
        switch self {
        case .pump: "drop"
        case .bottle: "waterbottle"
        case .nursing: "heart"
        case .sleep: "moon.zzz"
        case .diaper: "leaf"
        case .checklistConfirmation: "checkmark.circle"
        }
    }

    var activityIcon: ActivityIcon? {
        switch self {
        case .pump: .pump
        case .bottle: .bottle
        case .nursing: .nursing
        case .sleep: .sleep
        case .diaper: .diaper
        case .checklistConfirmation: nil
        }
    }

    var category: TrackingCategory {
        switch self {
        case .pump: .pump
        case .bottle, .nursing: .feed
        case .sleep: .sleep
        case .diaper: .diaper
        case .checklistConfirmation: .other
        }
    }
}

struct DeveloperLauncherSection: View {
    @Binding var destination: DeveloperLoggerDestination?

    private let columns = [
        GridItem(.flexible(), spacing: BabyLogTheme.cardSpacing),
        GridItem(.flexible(), spacing: BabyLogTheme.cardSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            Text("DEVELOPER")
                .font(AppFont.eyebrow)
                .foregroundStyle(BabyLogTheme.brown700)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: BabyLogTheme.cardSpacing) {
                ForEach(DeveloperLoggerDestination.allCases) { logger in
                    Button {
                        destination = logger
                    } label: {
                        HStack(spacing: 8) {
                            if let icon = logger.activityIcon {
                                ActivityIconView(icon: icon, color: logger.category.style.main)
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: logger.systemImage)
                            }
                            Text(logger.title)
                        }
                            .font(AppFont.primaryRow)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(logger.category.style.main)
                    .accessibilityIdentifier("developer-launcher-\(logger.rawValue)")
                }
            }
        }
        .padding(BabyLogTheme.horizontalPadding)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
        .shadow(
            color: BabyLogTheme.shadowColor,
            radius: BabyLogTheme.shadowRadius,
            x: BabyLogTheme.shadowOffset.width,
            y: BabyLogTheme.shadowOffset.height
        )
    }
}

struct DeveloperLoggerPlaceholderSheet: View {
    let destination: DeveloperLoggerDestination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: BabyLogTheme.cardSpacing) {
                if let icon = destination.activityIcon {
                    ActivityIconView(icon: icon, color: destination.category.style.main)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: destination.systemImage)
                        .font(.system(size: 32))
                        .foregroundStyle(destination.category.style.main)
                }

                Text("\(destination.title) logger")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(BabyLogTheme.ink)

                Text("DEBUG placeholder — implemented in a later phase.")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
                    .multilineTextAlignment(.center)
            }
            .padding(BabyLogTheme.headingPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(destination.category.style.soft)
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("developer-placeholder-dismiss")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
#endif
