import SwiftUI

struct ChecklistLoggingSheet: View {
    let access: BabyAccess?
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ChecklistItem] = []
    @State private var events: [ChecklistEvent] = []
    @State private var selectedItem: ChecklistItem?
    @State private var editingItem: ChecklistItem?
    @State private var showsAddItem = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        ContentUnavailableView("No checklist items", systemImage: "checklist", description: Text(emptyChecklistMessage))
                        if access != nil, errorMessage == nil {
                            Button("Add Item") { showsAddItem = true }
                                .buttonStyle(.borderedProminent)
                        } else if access != nil {
                            Button("Retry") { Task { await load() } }
                                .buttonStyle(.bordered)
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach(items) { item in row(item) }
                            .onMove(perform: move)
                        } header: {
                            Text("Daily Checklist")
                        } footer: {
                            Text("\(completionMap.count) of \(items.count) done")
                        }
                        if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle("Checklist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .confirmationAction) {
                    EditButton().disabled(access == nil)
                    Button { showsAddItem = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add checklist item")
                        .disabled(access == nil)
                }
            }
        }
        .tint(TrackingCategory.other.style.main)
        .babyLogSheetPresentation()
        .task(id: access?.baby.id) { await load() }
        .sheet(item: $selectedItem) { item in
            ChecklistConfirmationSheet(item: item, userID: access?.membership.userID ?? "", event: completionMap[item.id], onSaved: saveEvent, onDelete: deleteEvent)
        }
        .sheet(isPresented: $showsAddItem) { itemEditor(nil) }
        .sheet(item: $editingItem) { item in itemEditor(item) }
    }

    private var completionMap: [String: ChecklistEvent] { ChecklistLogic.completionByItem(events) }

    private var emptyChecklistMessage: String {
        if access == nil { return "Sign in and select a baby to load the checklist." }
        return errorMessage ?? "Add an item to begin."
    }

    private func row(_ item: ChecklistItem) -> some View {
        let event = completionMap[item.id]
        return Button { selectedItem = item } label: {
            HStack(spacing: 12) {
                Image(systemName: item.symbol)
                    .frame(width: 44, height: 44)
                    .background(event == nil ? BabyLogTheme.surface : BabyLogTheme.brown700)
                    .foregroundStyle(event == nil ? BabyLogTheme.brown500 : .white)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(BabyLogTheme.divider) }
                VStack(alignment: .leading) {
                    Text(item.title).font(AppFont.primaryRow)
                    if let event { Text(event.timestamp, formatter: AppFormatters.time()).font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText) }
                }
                Spacer()
                Button { editingItem = item } label: { Image(systemName: "ellipsis") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(item.title)")
            }
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("Remove", role: .destructive) { Task { await deactivate(item) } }
        }
    }

    @ViewBuilder private func itemEditor(_ item: ChecklistItem?) -> some View {
        if let access {
            ChecklistItemEditorSheet(item: item, babyID: access.baby.id, userID: access.membership.userID, sortOrder: items.count) { value in
                if item == nil { try await environment.checklistRepository.createItem(value) }
                else { try await environment.checklistRepository.updateItem(value) }
            }
        }
    }

    @MainActor private func load() async {
        guard let access else { return }
        do {
            try await environment.checklistRepository.seedDefaultsIfNeeded(babyID: access.baby.id, userID: access.membership.userID)
            async let itemLoop: Void = observeItems(access.baby.id)
            async let eventLoop: Void = observeEvents(access.baby.id)
            _ = try await (itemLoop, eventLoop)
        } catch { errorMessage = "Checklist is unavailable. Try again when the connection returns." }
    }

    @MainActor private func observeItems(_ babyID: String) async throws {
        for try await values in environment.checklistRepository.observeItems(babyID: babyID) { items = values }
    }

    @MainActor private func observeEvents(_ babyID: String) async throws {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: .now)
        let interval = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
        for try await values in environment.checklistRepository.observeEvents(babyID: babyID, interval: interval) { events = values }
    }

    private func saveEvent(_ event: ChecklistEvent) async throws {
        if completionMap[event.checklistItemID] == nil { try await environment.checklistRepository.createEvent(event) }
        else { _ = try await environment.checklistRepository.updateEvent(event) }
    }

    private func deleteEvent(_ event: ChecklistEvent) async throws { try await environment.checklistRepository.deleteEvent(id: event.id, babyID: event.babyID) }

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        let reordered = items
        Task { do { try await environment.checklistRepository.reorder(reordered) } catch { errorMessage = "Couldn’t reorder items." } }
    }

    @MainActor private func deactivate(_ item: ChecklistItem) async {
        var updated = item
        updated.isActive = false
        do { try await environment.checklistRepository.updateItem(updated) }
        catch { errorMessage = "Couldn’t remove the item." }
    }
}
