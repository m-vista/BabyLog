import SwiftUI

struct PumpDurationEditor: View {
    let title: LocalizedStringKey
    @Binding var durationSeconds: TimeInterval

    @State private var showsPicker = false

    var body: some View {
        Button {
            showsPicker = true
        } label: {
            HStack {
                Text(title)
                    .font(AppFont.loggingRow)
                Spacer()
                Text(durationText)
                    .font(AppFont.loggingValue)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
            .foregroundStyle(BabyLogTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showsPicker) {
            VStack(spacing: 0) {
                HStack {
                    Text(title).font(AppFont.loggingRow)
                    Spacer()
                    Button("Done") { showsPicker = false }
                        .font(AppFont.loggingRow)
                }
                .padding(.horizontal)

                HStack(spacing: 0) {
                    Picker("Hours", selection: hoursBinding) {
                        ForEach(0...23, id: \.self) { Text("\($0) hr").tag($0) }
                    }
                    Picker("Minutes", selection: minutesBinding) {
                        ForEach(0...59, id: \.self) { Text("\($0) min").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .background(BabyLogTheme.cream.ignoresSafeArea())
            .presentationDetents([.height(330)])
            .presentationBackground(BabyLogTheme.cream)
            .presentationBackgroundInteraction(.enabled)
        }
    }

    private var totalMinutes: Int { max(0, Int((durationSeconds / 60).rounded())) }
    private var durationText: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    private var hoursBinding: Binding<Int> {
        Binding(get: { totalMinutes / 60 }, set: { durationSeconds = TimeInterval(($0 * 60 + totalMinutes % 60) * 60) })
    }
    private var minutesBinding: Binding<Int> {
        Binding(get: { totalMinutes % 60 }, set: { durationSeconds = TimeInterval((totalMinutes / 60 * 60 + $0) * 60) })
    }
}

struct OptionalDurationEditor: View {
    let title: LocalizedStringKey
    @Binding var durationSeconds: TimeInterval?

    @State private var draftMinutes = 1
    @State private var showsPicker = false

    var body: some View {
        Button {
            draftMinutes = max(1, Int(((durationSeconds ?? 60) / 60).rounded()))
            showsPicker = true
        } label: {
            HStack {
                Text(title).font(AppFont.loggingRow)
                Spacer()
                Text(durationText)
                    .font(AppFont.loggingValue)
                    .foregroundStyle(durationSeconds == nil ? BabyLogTheme.mutedText : BabyLogTheme.ink)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
            .foregroundStyle(BabyLogTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showsPicker) {
            VStack(spacing: 0) {
                HStack {
                    Text(title).font(AppFont.loggingRow)
                    Spacer()
                    Button("Done") {
                        durationSeconds = TimeInterval(draftMinutes * 60)
                        showsPicker = false
                    }
                    .font(AppFont.loggingRow)
                }
                .padding(.horizontal)

                HStack(spacing: 0) {
                    Picker("Hours", selection: hoursBinding) {
                        ForEach(0...23, id: \.self) { Text("\($0) hr").tag($0) }
                    }
                    Picker("Minutes", selection: minutesBinding) {
                        ForEach(0...59, id: \.self) { Text("\($0) min").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .background(BabyLogTheme.cream.ignoresSafeArea())
            .presentationDetents([.height(330)])
            .presentationBackground(BabyLogTheme.cream)
            .presentationBackgroundInteraction(.enabled)
        }
    }

    private var durationText: String {
        guard let durationSeconds else { return "—" }
        let minutes = max(0, Int((durationSeconds / 60).rounded()))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
    private var hoursBinding: Binding<Int> {
        Binding(get: { draftMinutes / 60 }, set: { draftMinutes = $0 * 60 + draftMinutes % 60 })
    }
    private var minutesBinding: Binding<Int> {
        Binding(get: { draftMinutes % 60 }, set: { draftMinutes = draftMinutes / 60 * 60 + $0 })
    }
}
