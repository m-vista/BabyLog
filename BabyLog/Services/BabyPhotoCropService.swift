import CoreGraphics

/// The local presentation choices for a baby's fixed-height header photo.
struct BabyPhotoCrop: Codable, Equatable {
    var zoom: Double
    var horizontalPosition: Double
    var verticalPosition: Double

    static let `default` = BabyPhotoCrop(zoom: 1, horizontalPosition: 0, verticalPosition: 0)
}

struct BabyPhotoCropLayout: Equatable {
    let renderedSize: CGSize
    let offset: CGSize
}

enum BabyPhotoCropService {
    static let zoomRange = 1.0...3.0
    static let positionRange = -1.0...1.0

    static func layout(imageSize: CGSize, in frameSize: CGSize, crop: BabyPhotoCrop) -> BabyPhotoCropLayout {
        guard imageSize.width > 0, imageSize.height > 0, frameSize.width > 0, frameSize.height > 0 else {
            return BabyPhotoCropLayout(renderedSize: .zero, offset: .zero)
        }

        let baseScale = max(frameSize.width / imageSize.width, frameSize.height / imageSize.height)
        let zoom = CGFloat(clamped(crop.zoom, to: zoomRange))
        let renderedSize = CGSize(
            width: imageSize.width * baseScale * zoom,
            height: imageSize.height * baseScale * zoom
        )
        let maximumOffset = CGSize(
            width: max(0, (renderedSize.width - frameSize.width) / 2),
            height: max(0, (renderedSize.height - frameSize.height) / 2)
        )
        return BabyPhotoCropLayout(
            renderedSize: renderedSize,
            offset: CGSize(
                width: maximumOffset.width * CGFloat(clamped(crop.horizontalPosition, to: positionRange)),
                height: maximumOffset.height * CGFloat(clamped(crop.verticalPosition, to: positionRange))
            )
        )
    }

    static func crop(
        afterDrag translation: CGSize,
        from crop: BabyPhotoCrop,
        imageSize: CGSize,
        frameSize: CGSize
    ) -> BabyPhotoCrop {
        let layout = layout(imageSize: imageSize, in: frameSize, crop: crop)
        guard layout.renderedSize != .zero else { return crop }

        let maximumOffset = CGSize(
            width: max(0, (layout.renderedSize.width - frameSize.width) / 2),
            height: max(0, (layout.renderedSize.height - frameSize.height) / 2)
        )
        return BabyPhotoCrop(
            zoom: crop.zoom,
            horizontalPosition: position(after: translation.width, current: crop.horizontalPosition, maximumOffset: maximumOffset.width),
            verticalPosition: position(after: translation.height, current: crop.verticalPosition, maximumOffset: maximumOffset.height)
        )
    }

    static func crop(afterMagnification magnification: CGFloat, from crop: BabyPhotoCrop) -> BabyPhotoCrop {
        BabyPhotoCrop(
            zoom: clamped(crop.zoom * Double(magnification), to: zoomRange),
            horizontalPosition: clamped(crop.horizontalPosition, to: positionRange),
            verticalPosition: clamped(crop.verticalPosition, to: positionRange)
        )
    }

    private static func position(after translation: CGFloat, current: Double, maximumOffset: CGFloat) -> Double {
        guard maximumOffset > 0 else { return 0 }
        return clamped(current + Double(translation / maximumOffset), to: positionRange)
    }

    private static func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
