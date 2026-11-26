import PhotosUI
import SwiftUI

@MainActor
struct BabyPhotoPicker: View {
    let babyID: String

    @Environment(AppEnvironment.self) private var environment
    @State private var selectedItem: PhotosPickerItem?
    @State private var pendingPhoto: PendingPhoto?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 12) {
                    photoPreview
                    VStack(alignment: .leading, spacing: 2) {
                        Text(environment.babyPhotoStore.image(for: babyID) == nil ? "Add baby photo" : "Change baby photo")
                            .font(AppFont.primaryRow)
                        Text("Stored only on this device.")
                            .font(AppFont.secondary)
                            .foregroundStyle(BabyLogTheme.mutedText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(BabyLogTheme.mutedText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if environment.babyPhotoStore.image(for: babyID) != nil {
                Button("Remove photo", role: .destructive) {
                    removePhoto()
                }
                .font(AppFont.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.secondary)
                    .foregroundStyle(.red)
            }
        }
        .task(id: babyID) {
            environment.babyPhotoStore.loadPhoto(for: babyID)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await preparePhoto(from: newItem) }
        }
        .sheet(item: $pendingPhoto, onDismiss: { selectedItem = nil }) { pendingPhoto in
            BabyPhotoCropEditor(image: pendingPhoto.image) { crop in
                savePhoto(pendingPhoto.data, crop: crop)
            }
        }
    }

    private var photoPreview: some View {
        Group {
            if let image = environment.babyPhotoStore.image(for: babyID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                    .foregroundStyle(BabyLogTheme.brown700)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BabyLogTheme.brown100)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(BabyLogTheme.divider)
        }
    }

    private func preparePhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "The selected photo couldn’t be loaded."
                return
            }
            guard let image = UIImage(data: data) else {
                errorMessage = "The selected photo couldn’t be loaded."
                return
            }
            pendingPhoto = PendingPhoto(data: data, image: image)
            errorMessage = nil
        } catch {
            errorMessage = "The selected photo couldn’t be loaded."
        }
    }

    private func savePhoto(_ data: Data, crop: BabyPhotoCrop) {
        do {
            try environment.babyPhotoStore.savePhoto(data, crop: crop, for: babyID)
            errorMessage = nil
        } catch {
            errorMessage = "The photo couldn’t be saved on this device."
        }
    }

    private func removePhoto() {
        do {
            try environment.babyPhotoStore.removePhoto(for: babyID)
            errorMessage = nil
        } catch {
            errorMessage = "The photo couldn’t be removed."
        }
    }
}

private struct PendingPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let image: UIImage
}
