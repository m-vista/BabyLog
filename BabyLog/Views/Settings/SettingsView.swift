import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    let access: BabyAccess
    let onAccessUpdated: (BabyAccess) -> Void
    @State private var preferences = UserPreferences.defaults
    @State private var saveTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var showsDayStartPicker = false

    init(access: BabyAccess, onAccessUpdated: @escaping (BabyAccess) -> Void = { _ in }) {
        self.access = access; self.onAccessUpdated = onAccessUpdated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SettingsHeader()
                    NavigationLink { BabySettingsEditor(access: access, onSaved: onAccessUpdated) } label: { SettingsBabyCard(baby: access.baby).contentShape(Rectangle()) }.buttonStyle(.plain)
                    appearanceGroup
                    trackingGroup
                    smartDefaultsGroup
                    pumpingGroup
                    navigationGroup
                    SettingsDataTransferSection(access: access)
                    accountGroup
                    if let errorMessage { Text(errorMessage).font(AppFont.secondary).foregroundStyle(.red) }
                }
                .padding(.horizontal, 16).padding(.top, 56)
                .padding(.bottom, BabyLogTheme.tabBarItemHeight + 32)
            }
            .scrollIndicators(.hidden).background(BabyLogTheme.cream).ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { preferences = environment.preferences.values }
        .onChange(of: preferences) { _, value in persist(value) }
        .sheet(isPresented: $showsDayStartPicker) {
            DayStartPickerSheet(minutes: $preferences.dayStartMinutes)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
    }

    private var appearanceGroup: some View {
        SettingsGroup(title: "APPEARANCE") {
            MenuRow(title: "Color mode", value: preferences.appearanceMode.title, showsDivider: false) {
                Picker("Color mode", selection: $preferences.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
            }
        }
    }

    private var trackingGroup: some View {
        SettingsGroup(title: "TRACKING") {
            Button { showsDayStartPicker = true } label: {
                SettingsValueRow(title: "Day starts at", value: SettingsTime.minutes(preferences.dayStartMinutes))
            }
            .buttonStyle(.plain)
            MenuRow(title: "Volume unit", value: preferences.volumeUnit.rawValue) {
                Picker("Volume unit", selection: $preferences.volumeUnit) { ForEach(VolumeUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.labelsHidden()
            }
            MenuRow(title: "Growth units", value: preferences.growthUnitSystem.title) {
                Picker("Growth units", selection: $preferences.growthUnitSystem) {
                    ForEach(GrowthUnitSystem.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
            }
            SettingsToggleRow(title: "Show relative times", value: $preferences.showRelativeTimes)
            if preferences.dayStartMinutes != 0 {
                SettingsToggleRow(title: "Use in Timeline", value: $preferences.useCustomDayInTimeline)
                SettingsToggleRow(title: "Use in Calendar", value: $preferences.useCustomDayInCalendar)
                SettingsToggleRow(title: "Use in Analytics", value: $preferences.useCustomDayInAnalytics, showsDivider: false)
            }
        }
    }

    private var smartDefaultsGroup: some View {
        SettingsGroup(title: "SMART DEFAULTS") {
            SettingsToggleRow(title: "Remember pump duration", value: $preferences.rememberPumpDuration)
            SettingsToggleRow(title: "Remember diaper size", value: $preferences.rememberDiaperSize)
            MenuRow(title: "Bottle autofill", value: preferences.bottleAutofill == .lastUsed ? "On" : "Off", showsDivider: false) {
                Picker("Bottle autofill", selection: $preferences.bottleAutofill) { Text("On").tag(BottleAutofill.lastUsed); Text("Off").tag(BottleAutofill.off) }.labelsHidden()
            }
        }
    }

    private var pumpingGroup: some View {
        SettingsGroup(title: "PUMPING") {
            SettingsToggleRow(title: "Show production rate", value: $preferences.showPumpRate)
            SettingsToggleRow(title: "Separate post-nursing pumps", helper: "Keep them out of clean-rate averages", value: $preferences.separatePostNursingPumps)
            NavigationLink { NursingEstimateAveragesView(access: access) } label: { SettingsChevronRow(title: "See current averages", showsDivider: false).contentShape(Rectangle()) }.buttonStyle(.plain)
        }
    }

    private var navigationGroup: some View {
        SettingsGroup(title: "OTHER") {
            NavigationLink { ChecklistManagementView(access: access) } label: { SettingsChevronRow(title: "Manage Daily Checklist").contentShape(Rectangle()) }.buttonStyle(.plain)
            if access.membership.role == .owner {
                NavigationLink { AddCaregiverView(babyID: access.baby.id) } label: { SettingsChevronRow(title: "Add Caregiver", showsDivider: false).contentShape(Rectangle()) }.buttonStyle(.plain)
            }
        }
    }

    private var accountGroup: some View {
        SettingsGroup(title: "ACCOUNT") {
            NavigationLink { AccountSettingsView(userID: access.membership.userID) } label: { SettingsChevronRow(title: "Account").contentShape(Rectangle()) }.buttonStyle(.plain)
            Button(role: .destructive) { try? environment.authService.signOut() } label: { Text("Sign Out").font(AppFont.primaryRow).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading) }.buttonStyle(.plain)
        }
    }

    private func persist(_ value: UserPreferences) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do { try await environment.preferences.update(value, userID: access.membership.userID) }
            catch { errorMessage = "Settings couldn’t be saved. Try again." }
        }
    }
}

private struct SettingsHeader: View {
    var body: some View { VStack(alignment:.leading,spacing:3){Text("BABYLOG").font(AppFont.eyebrow).tracking(1.2).foregroundStyle(BabyLogTheme.mutedText);Text("Settings").font(.title2.bold()).foregroundStyle(BabyLogTheme.ink)}.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,4) }
}

private struct SettingsBabyCard: View {
    let baby: Baby
    var body: some View {
        HStack(spacing:14){Text(String(baby.name.prefix(1)).uppercased()).font(.headline).frame(width:50,height:50).background(BabyLogTheme.brown500).clipShape(Circle()).overlay{Circle().stroke(.white.opacity(0.35),lineWidth:2)};VStack(alignment:.leading,spacing:2){Text(baby.name).font(.headline).lineLimit(2);Text("\(age) · Born \(baby.birthDate.formatted(date:.abbreviated,time:.omitted))").font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.85))};Spacer();Image(systemName:"chevron.right").foregroundStyle(.white.opacity(0.85))}
        .foregroundStyle(.white).padding(.horizontal,16).padding(.vertical,14).background(BabyLogTheme.heroGradient).clipShape(RoundedRectangle(cornerRadius:6)).shadow(color:BabyLogTheme.shadowColorStrong,radius:14,y:4)
    }
    private var age: String {
        let calendar = Calendar.autoupdatingCurrent
        let birthDay = calendar.startOfDay(for: baby.birthDate)
        let currentDay = calendar.startOfDay(for: .now)
        let components = calendar.dateComponents([.year, .month], from: birthDay, to: currentDay)
        if let years = components.year, years > 0 {
            return "\(years)y (\(max(components.month ?? 0, 0))m)"
        }
        let days = max(0, calendar.dateComponents([.day], from: birthDay, to: currentDay).day ?? 0)
        return "\(days / 7)w"
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title).font(AppFont.eyebrow).tracking(1.2).foregroundStyle(BabyLogTheme.mutedText).padding(.horizontal, 4); VStack(spacing: 0) { content }.padding(.horizontal, 16).background(BabyLogTheme.surface).clipShape(RoundedRectangle(cornerRadius: 5)).shadow(color: BabyLogTheme.shadowColor, radius: 10, y: 2) } }
}

struct SettingsToggleRow: View { let title:String;var helper:String?;@Binding var value:Bool;var showsDivider=true;var body:some View{HStack{VStack(alignment:.leading,spacing:2){Text(title).font(AppFont.primaryRow).foregroundStyle(BabyLogTheme.ink);if let helper{Text(helper).font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText)}};Spacer();Toggle("",isOn:$value).labelsHidden().tint(TrackingCategory.diaper.style.main).accessibilityLabel(title)}.padding(.vertical,4).frame(minHeight:helper == nil ? 48:58).overlay(alignment:.bottom){if showsDivider{Rectangle().fill(BabyLogTheme.divider).frame(height:1)}}}}

struct MenuRow<Content: View>: View {
    let title: String; let value: String; var showsDivider = true
    @ViewBuilder let content: Content
    init(title: String, value: String, showsDivider: Bool = true, @ViewBuilder content: () -> Content) { self.title = title; self.value = value; self.showsDivider = showsDivider; self.content = content() }
    var body: some View { HStack { Text(title).font(AppFont.primaryRow).foregroundStyle(BabyLogTheme.ink); Spacer(); Menu { content } label: { HStack(spacing: 6) { Text(value).font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(BabyLogTheme.mutedText) } }.accessibilityLabel("\(title), \(value)") }.frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle()).overlay(alignment: .bottom) { if showsDivider { Rectangle().fill(BabyLogTheme.divider).frame(height: 1) } } }
}

struct SettingsChevronRow: View { let title:String;var showsDivider=true;var body:some View{HStack{Text(title).font(AppFont.primaryRow);Spacer();Image(systemName:"chevron.right").font(.caption.bold()).foregroundStyle(BabyLogTheme.mutedText).accessibilityHidden(true)}.foregroundStyle(BabyLogTheme.ink).frame(maxWidth:.infinity,minHeight:48).contentShape(Rectangle()).overlay(alignment:.bottom){if showsDivider{Rectangle().fill(BabyLogTheme.divider).frame(height:1)}}}}

struct SettingsValueRow: View {
    let title: String
    let value: String
    var showsChevron = true
    var showsDivider = true

    var body: some View {
        HStack {
            Text(title).font(AppFont.primaryRow).foregroundStyle(BabyLogTheme.ink)
            Spacer()
            Text(value).font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText)
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(BabyLogTheme.mutedText).accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { if showsDivider { Rectangle().fill(BabyLogTheme.divider).frame(height: 1) } }
    }
}

private struct DayStartPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var minutes: Int
    @State private var selection: Date

    init(minutes: Binding<Int>) {
        _minutes = minutes
        _selection = State(initialValue: SettingsTime.date(minutes.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Day starts at").font(.headline).foregroundStyle(BabyLogTheme.ink)
                Spacer()
                Button("Done") {
                    minutes = SettingsTime.minutes(selection)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .foregroundStyle(BabyLogTheme.brown700)
            .padding(.horizontal, 20)
            .frame(minHeight: 52)

            Divider()

            DatePicker("Day starts at", selection: $selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BabyLogTheme.cream.ignoresSafeArea())
    }
}

enum SettingsTime { static func date(_ minutes:Int)->Date{Calendar.autoupdatingCurrent.startOfDay(for:.now).addingTimeInterval(Double(minutes*60))};static func minutes(_ date:Date)->Int{let c=Calendar.autoupdatingCurrent.dateComponents([.hour,.minute],from:date);return (c.hour ?? 0)*60+(c.minute ?? 0)};static func minutes(_ minutes:Int)->String{AppFormatters.time().string(from:date(minutes))} }
