import Foundation
import Testing
import UIKit
@testable import BabyLog

@MainActor
struct BabyPhotoStoreTests {
    @Test func photoPersistsOnlyInTheLocalStoreAndCanBeRemoved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "BabyPhotoStoreTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.systemBrown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let data = try #require(image.pngData())
        let store = BabyPhotoStore(directory: directory)

        try store.savePhoto(data, for: "baby")
        #expect(store.image(for: "baby") != nil)

        let reloadedStore = BabyPhotoStore(directory: directory)
        reloadedStore.loadPhoto(for: "baby")
        #expect(reloadedStore.image(for: "baby") != nil)

        try reloadedStore.removePhoto(for: "baby")
        #expect(reloadedStore.image(for: "baby") == nil)
    }

    @Test func photoCropPersistsLocallyWithThePhoto() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "BabyPhotoStoreTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.systemBrown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let crop = BabyPhotoCrop(zoom: 1.8, horizontalPosition: -0.25, verticalPosition: 0.6)
        let store = BabyPhotoStore(directory: directory)

        try store.savePhoto(#require(image.pngData()), crop: crop, for: "baby")

        let reloadedStore = BabyPhotoStore(directory: directory)
        reloadedStore.loadPhoto(for: "baby")
        #expect(reloadedStore.crop(for: "baby") == crop)
    }

    @Test func cropLayoutAndGesturesStayWithinTheHeaderBounds() {
        let imageSize = CGSize(width: 100, height: 200)
        let frameSize = CGSize(width: 300, height: 190)
        let centered = BabyPhotoCropService.layout(imageSize: imageSize, in: frameSize, crop: .default)

        #expect(centered.renderedSize == CGSize(width: 300, height: 600))
        #expect(centered.offset == .zero)

        let panned = BabyPhotoCropService.crop(
            afterDrag: CGSize(width: 0, height: 102.5),
            from: .default,
            imageSize: imageSize,
            frameSize: frameSize
        )
        #expect(panned.verticalPosition == 0.5)

        let zoomed = BabyPhotoCropService.crop(afterMagnification: 10, from: panned)
        #expect(zoomed.zoom == 3)
        #expect(zoomed.verticalPosition == 0.5)
    }
}
