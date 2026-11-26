import SwiftUI

struct EditableDateTimeCard: View {
    let title: LocalizedStringKey
    @Binding var date: Date
    let category: TrackingCategory
    var icon: ActivityIcon?
    var minimumDate: Date?
    var isEnabled = true

    @State private var showsPicker = false

    var body: some View {
        Button {
            showsPicker = true
        } label: {
            HStack(spacing: BabyLogTheme.cardSpacing) {
                if let icon {
                    ActivityIconView(icon: icon, color: category.style.main)
                        .frame(width: 24, height: 24)
                        .frame(width: 40, height: 40)
                        .background(BabyLogTheme.surface)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppFont.secondary)
                        .foregroundStyle(category.style.text)
                    Text(displayText)
                        .font(AppFont.loggingValue)
                        .foregroundStyle(BabyLogTheme.ink)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(category.style.text.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(category.style.soft)
            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .sheet(isPresented: $showsPicker) {
            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(AppFont.loggingRow)
                    Spacer()
                    Button("Done") { showsPicker = false }
                        .font(AppFont.loggingRow)
                }
                .padding(.horizontal)

                Group {
                    if let minimumDate {
                        DatePicker("", selection: $date, in: minimumDate..., displayedComponents: [.date, .hourAndMinute])
                    } else {
                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                .labelsHidden()
                .datePickerStyle(.wheel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BabyLogTheme.cream.ignoresSafeArea())
            .presentationDetents([.height(330)])
            .presentationBackground(BabyLogTheme.cream)
            .presentationCornerRadius(BabyLogTheme.radiusLarge)
            .presentationBackgroundInteraction(.enabled)
        }
    }

    private var displayText: String {
        if Calendar.autoupdatingCurrent.isDateInToday(date) {
            return AppFormatters.time().string(from: date)
        }
        return AppFormatters.dateAndTime().string(from: date)
    }
}

struct OptionalEditableDateTimeCard: View {
    let title: LocalizedStringKey
    @Binding var date: Date?
    let category: TrackingCategory
    var minimumDate: Date?
    var isEnabled = true

    @State private var draftDate = Date.now
    @State private var showsPicker = false

    var body: some View {
        Button {
            let earliest = minimumDate?.addingTimeInterval(0.001) ?? .distantPast
            draftDate = max(date ?? .now, earliest)
            showsPicker = true
        } label: {
            HStack(spacing: BabyLogTheme.cardSpacing) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppFont.secondary)
                        .foregroundStyle(category.style.text)
                    Text(displayText)
                        .font(AppFont.loggingValue)
                        .foregroundStyle(date == nil ? BabyLogTheme.mutedText : BabyLogTheme.ink)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(category.style.text.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(category.style.soft)
            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .sheet(isPresented: $showsPicker) {
            VStack(spacing: 0) {
                HStack {
                    Text(title).font(AppFont.loggingRow)
                    Spacer()
                    Button("Done") {
                        date = draftDate
                        showsPicker = false
                    }
                    .font(AppFont.loggingRow)
                }
                .padding(.horizontal)

                Group {
                    if let minimumDate {
                        DatePicker("", selection: $draftDate, in: minimumDate.addingTimeInterval(0.001)..., displayedComponents: [.date, .hourAndMinute])
                    } else {
                        DatePicker("", selection: $draftDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                .labelsHidden()
                .datePickerStyle(.wheel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BabyLogTheme.cream.ignoresSafeArea())
            .presentationDetents([.height(330)])
            .presentationBackground(BabyLogTheme.cream)
            .presentationCornerRadius(BabyLogTheme.radiusLarge)
            .presentationBackgroundInteraction(.enabled)
        }
    }

    private var displayText: String {
        guard let date else { return "Not set" }
        if Calendar.autoupdatingCurrent.isDateInToday(date) {
            return AppFormatters.time().string(from: date)
        }
        return AppFormatters.dateAndTime().string(from: date)
    }
}
