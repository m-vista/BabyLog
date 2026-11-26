import Foundation
import Observation
import UIKit

/// Stores a baby's header photo on the current device only.
@MainActor
@Observable
final class BabyPhotoStore {
    private let directory: URL
    private let fileManager: FileManager
    private var images: [String: UIImage] = [:]
    private var crops: [String: BabyPhotoCrop] = [:]
    private var loadedBabyIDs: Set<String> = []

    init(
        directory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directory = directory ?? Self.defaultDirectory(fileManager: fileManager)
    }

    func image(for babyID: String) -> UIImage? {
        images[babyID]
    }

    func crop(for babyID: String) -> BabyPhotoCrop {
        crops[babyID] ?? .default
    }

    func loadPhoto(for babyID: String) {
        guard !loadedBabyIDs.contains(babyID) else { return }
        loadedBabyIDs.insert(babyID)

        guard let data = try? Data(contentsOf: fileURL(for: babyID)),
              let image = UIImage(data: data)
        else {
            return
        }

        images[babyID] = image
        crops[babyID] = (try? JSONDecoder().decode(BabyPhotoCrop.self, from: Data(contentsOf: cropURL(for: babyID)))) ?? .default
    }

    func savePhoto(_ data: Data, crop: BabyPhotoCrop = .default, for babyID: String) throws {
        guard let image = UIImage(data: data) else {
            throw BabyPhotoStoreError.invalidPhotoData
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: babyID), options: .atomic)
        try JSONEncoder().encode(crop).write(to: cropURL(for: babyID), options: .atomic)
        loadedBabyIDs.insert(babyID)
        images[babyID] = image
        crops[babyID] = crop
    }

    func removePhoto(for babyID: String) throws {
        let url = fileURL(for: babyID)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        let cropURL = cropURL(for: babyID)
        if fileManager.fileExists(atPath: cropURL.path) {
            try fileManager.removeItem(at: cropURL)
        }
        loadedBabyIDs.insert(babyID)
        images[babyID] = nil
        crops[babyID] = nil
    }

    private func fileURL(for babyID: String) -> URL {
        directory.appending(path: "\(babyID).photo")
    }

    private func cropURL(for babyID: String) -> URL {
        directory.appending(path: "\(babyID).crop")
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport.appending(path: "BabyPhotos")
    }
}

enum BabyPhotoStoreError: Error, Equatable {
    case invalidPhotoData
}
