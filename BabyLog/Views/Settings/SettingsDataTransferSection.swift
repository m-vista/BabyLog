import SwiftUI
import UniformTypeIdentifiers

struct SettingsDataTransferSection: View {
    @Environment(AppEnvironment.self) private var environment
    let access: BabyAccess

    @State private var showsImporter = false
    @State private var showsExporter = false
    @State private var pendingImport: DataTransferArchive?
    @State private var showsClashDialog = false
    @State private var exportDocument: CSVTransferDocument?
    @State private var exportFilename = "BabyLog Export"
    @State private var isWorking = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        SettingsGroup(title: "DATA") {
            Button { showsImporter = true } label: {
                SettingsChevronRow(title: "Import data")
            }
            .buttonStyle(.plain)
            .disabled(isWorking)

            Button { exportSample() } label: {
                SettingsChevronRow(title: "Download sample import CSV form")
            }
            .buttonStyle(.plain)
            .disabled(isWorking)

            Button { prepareExport() } label: {
                SettingsChevronRow(title: "Export data", showsDivider: false)
            }
            .buttonStyle(.plain)
            .disabled(isWorking)

            if isWorking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Preparing data…")
                }
                .font(.caption)
                .foregroundStyle(BabyLogTheme.mutedText)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.commaSeparatedText]) { result in
            handleImportSelection(result)
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { result in
            if case .failure = result { errorMessage = "The CSV couldn’t be saved. Try again." }
            exportDocument = nil
        }
        .confirmationDialog(
            "How should matching records be handled?",
            isPresented: $showsClashDialog,
            titleVisibility: .visible
        ) {
            Button("Keep existing") { runImport(policy: .keepExisting) }
            Button("Replace with imported data", role: .destructive) { runImport(policy: .replaceWithImported) }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            Text("This choice applies to every matching record in this file.")
        }
        .alert("Import complete", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
        .alert("Data transfer failed", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func exportSample() {
        exportDocument = CSVTransferDocument(text: DataTransferCSV.sample)
        exportFilename = "BabyLog Import Template"
        showsExporter = true
    }

    private func prepareExport() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let archive = try await DataTransferService(environment: environment, access: access).exportArchive()
                exportDocument = CSVTransferDocument(text: DataTransferCSV.encode(archive))
                exportFilename = "BabyLog \(access.baby.name) Export"
                showsExporter = true
            } catch {
                errorMessage = "BabyLog couldn’t prepare the export. Check your connection and try again."
            }
        }
    }

    private func handleImportSelection(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            errorMessage = "BabyLog couldn’t open that file."
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            pendingImport = try DataTransferCSV.decode(
                data,
                babyID: access.baby.id,
                userID: access.membership.userID
            )
            showsClashDialog = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runImport(policy: DataImportClashPolicy) {
        guard let archive = pendingImport else { return }
        pendingImport = nil
        showsClashDialog = false
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let result = try await DataTransferService(environment: environment, access: access)
                    .importArchive(archive, clashPolicy: policy)
                message = result.skipped == 0
                    ? "Imported \(result.imported) records."
                    : "Imported \(result.imported) records and kept \(result.skipped) existing records."
            } catch {
                errorMessage = "The import stopped because a record couldn’t be saved. Some earlier records may already have been imported."
            }
        }
    }
}
