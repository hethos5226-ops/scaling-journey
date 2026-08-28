import SwiftUI
import UIKit

/// Loads a stored photo asynchronously and shows a calm placeholder until it
/// arrives.
///
/// Photos live outside the database, so every view that shows one needs an
/// async load. Centralising it here means no screen reimplements the loading,
/// failure and cancellation behaviour.
struct SJPhotoImage<Placeholder: View>: View {
    var assetIdentifier: String?
    var variant: PhotoVariant
    @ViewBuilder var placeholder: Placeholder

    @Environment(AppDependencies.self) private var dependencies
    @State private var image: UIImage?
    @State private var loadedIdentifier: String?

    init(
        assetIdentifier: String?,
        variant: PhotoVariant = .thumbnail,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.assetIdentifier = assetIdentifier
        self.variant = variant
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .animation(Theme.Motion.quick, value: image == nil)
        // Keyed on the identifier so recycled rows in a scrolling list reload
        // rather than showing the previous row's photo.
        .task(id: assetIdentifier) {
            await load()
        }
    }

    private func load() async {
        guard let assetIdentifier else {
            image = nil
            loadedIdentifier = nil
            return
        }
        guard loadedIdentifier != assetIdentifier else { return }

        image = nil
        let loaded = await dependencies.photoStore.image(for: assetIdentifier, variant: variant)
        // The task can outlive the identifier it was started for.
        guard !Task.isCancelled else { return }
        image = loaded
        loadedIdentifier = assetIdentifier
    }
}

extension SJPhotoImage where Placeholder == SJPhotoPlaceholder {
    init(assetIdentifier: String?, variant: PhotoVariant = .thumbnail) {
        self.init(assetIdentifier: assetIdentifier, variant: variant) {
            SJPhotoPlaceholder()
        }
    }
}

/// Neutral fill shown while a photo loads, or when an entry has none.
struct SJPhotoPlaceholder: View {
    var systemImage: String = "camera"

    var body: some View {
        ZStack {
            Color.sjPhotoPlaceholder
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color.sjTertiaryText)
        }
    }
}

/// Small square photo used in lists.
struct SJPhotoThumbnail: View {
    var photo: PhotoSnapshot?
    var size: CGFloat

    var body: some View {
        SJPhotoImage(assetIdentifier: photo?.assetIdentifier, variant: .thumbnail)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A container with a fixed aspect ratio that its content fills and overflows,
/// cropped to a rounded rectangle.
///
/// Applying `.aspectRatio(_:contentMode: .fill)` directly to an image makes the
/// *image* drive the layout, so a portrait photo and a landscape one produce
/// differently sized cards. Sizing an empty `Color.clear` instead pins the
/// frame first and lets the photo fill it, which keeps every screen's rhythm
/// identical no matter what the user photographed.
struct SJAspectFill<Content: View>: View {
    var aspectRatio: CGFloat = 4.0 / 5.0
    var cornerRadius: CGFloat = Theme.Radius.photo
    @ViewBuilder var content: Content

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
