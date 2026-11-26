import SwiftUI
import UIKit

struct BabyPhotoCropEditor: View {
    let image: UIImage
    let initialCrop: BabyPhotoCrop
    let onSave: (BabyPhotoCrop) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var crop: BabyPhotoCrop
    @State private var gestureStartCrop: BabyPhotoCrop

    init(image: UIImage, initialCrop: BabyPhotoCrop = .default, onSave: @escaping (BabyPhotoCrop) -> Void) {
        self.image = image
        self.initialCrop = initialCrop
        self.onSave = onSave
        _crop = State(initialValue: initialCrop)
        _gestureStartCrop = State(initialValue: initialCrop)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("This is how your photo will appear in the Home header.")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)

                GeometryReader { proxy in
                    BabyPhotoCropPreview(image: image, crop: crop, showsGuides: true)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                        .gesture(dragGesture(in: proxy.size))
                        .simultaneousGesture(magnifyGesture)
                        .accessibilityLabel("Header photo preview")
                        .accessibilityHint("Drag to reposition the photo or pinch to zoom")
                }
                .frame(height: 190)

                Text("Drag to reposition. Pinch to zoom.")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)

                Button("Reset") {
                    crop = .default
                    gestureStartCrop = .default
                }
                .font(AppFont.primaryRow)
                .foregroundStyle(BabyLogTheme.brown700)

                Spacer()
            }
            .padding(20)
            .background(BabyLogTheme.cream)
            .navigationTitle("Position photo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use photo") {
                        onSave(crop)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func dragGesture(in frameSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                crop = BabyPhotoCropService.crop(
                    afterDrag: value.translation,
                    from: gestureStartCrop,
                    imageSize: image.size,
                    frameSize: frameSize
                )
            }
            .onEnded { _ in
                gestureStartCrop = crop
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                crop = BabyPhotoCropService.crop(afterMagnification: value.magnification, from: gestureStartCrop)
            }
            .onEnded { _ in
                gestureStartCrop = crop
            }
    }
}

struct BabyPhotoCropPreview: View {
    let image: UIImage
    let crop: BabyPhotoCrop
    var showsGuides = false

    var body: some View {
        GeometryReader { proxy in
            let layout = BabyPhotoCropService.layout(imageSize: image.size, in: proxy.size, crop: crop)
            Image(uiImage: image)
                .resizable()
                .frame(width: layout.renderedSize.width, height: layout.renderedSize.height)
                .offset(layout.offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay {
                    if showsGuides {
                        cropGuides
                    }
                }
        }
        .clipped()
    }

    private var cropGuides: some View {
        GeometryReader { proxy in
            Path { path in
                let thirdWidth = proxy.size.width / 3
                let thirdHeight = proxy.size.height / 3
                path.move(to: CGPoint(x: thirdWidth, y: 0))
                path.addLine(to: CGPoint(x: thirdWidth, y: proxy.size.height))
                path.move(to: CGPoint(x: thirdWidth * 2, y: 0))
                path.addLine(to: CGPoint(x: thirdWidth * 2, y: proxy.size.height))
                path.move(to: CGPoint(x: 0, y: thirdHeight))
                path.addLine(to: CGPoint(x: proxy.size.width, y: thirdHeight))
                path.move(to: CGPoint(x: 0, y: thirdHeight * 2))
                path.addLine(to: CGPoint(x: proxy.size.width, y: thirdHeight * 2))
            }
            .stroke(.white.opacity(0.45), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
