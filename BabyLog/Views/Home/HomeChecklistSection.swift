import SwiftUI

struct HomeChecklistSection: View {
    let items: [ChecklistItem]
    let completions: [String: ChecklistEvent]
    let onSelect: (ChecklistItem) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 2) {
                ForEach(items.prefix(5)) { item in checklistButton(item) }
                Button(action: onAdd) {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 50, height: 50)
                            .overlay { Circle().stroke(BabyLogTheme.brown500.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [4])) }
                        Text("Add").font(AppFont.eyebrow)
                    }
                }
                .foregroundStyle(BabyLogTheme.brown500)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, BabyLogTheme.horizontalPadding)
        .padding(.top, 22)
    }

    private func checklistButton(_ item: ChecklistItem) -> some View {
        let event = completions[item.id]
        return Button { onSelect(item) } label: {
            VStack(spacing: 10) {
                ZStack(alignment: .bottom) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 50, height: 50)
                        .background(event == nil ? BabyLogTheme.surface : BabyLogTheme.brown700)
                        .foregroundStyle(event == nil ? BabyLogTheme.brown500 : .white)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(BabyLogTheme.divider) }
                    if let event {
                        Text(event.timestamp, formatter: AppFormatters.time())
                            .font(AppFont.tag)
                            .foregroundStyle(BabyLogTheme.brown800)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(BabyLogTheme.surface)
                            .overlay { RoundedRectangle(cornerRadius: BabyLogTheme.radiusChip).stroke(BabyLogTheme.divider) }
                            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusChip))
                            .offset(y: -38)
                    }
                }
                Text(item.title).font(AppFont.eyebrow).foregroundStyle(event == nil ? BabyLogTheme.mutedText : BabyLogTheme.brown800).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(event == nil ? "\(item.title), incomplete" : "\(item.title), completed")
    }
}
