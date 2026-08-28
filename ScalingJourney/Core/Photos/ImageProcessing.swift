import Foundation
import UIKit

/// Downscaling and encoding rules for progress photos.
///
/// Photos are resized before they are written. A modern iPhone capture is
/// 12 MP and several megabytes; storing that untouched would bloat the app
/// container, make every future upload slow and expensive, and gain nothing
/// visible on a phone screen.
enum ImageProcessing {
    /// Longest edge of the stored full-size rendition, in pixels. Comfortably
    /// above the pixel height of the largest iPhone display, so full-screen
    /// and pinch-to-zoom viewing still look sharp.
    static let fullSizeMaxDimension: CGFloat = 2_048

    /// Longest edge of the thumbnail rendition.
    static let thumbnailMaxDimension: CGFloat = 480

    static let fullSizeCompressionQuality: CGFloat = 0.85
    static let thumbnailCompressionQuality: CGFloat = 0.7

    /// Returns a copy of `image` whose longest edge is at most `maxDimension`,
    /// with EXIF orientation baked in so downstream drawing never has to
    /// re-apply it. Images already small enough are still redrawn, which
    /// normalises orientation for every path.
    static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let longestEdge = max(size.width, size.height)
        let scale = longestEdge > maxDimension ? maxDimension / longestEdge : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// JPEG data for the given variant. JPEG rather than HEIC so exported data
    /// opens anywhere, which matters for the promised "export my data" flow.
    static func encode(_ image: UIImage, variant: PhotoVariant) throws -> (data: Data, pixelSize: CGSize) {
        let maxDimension = variant == .full ? fullSizeMaxDimension : thumbnailMaxDimension
        let quality = variant == .full ? fullSizeCompressionQuality : thumbnailCompressionQuality

        let resized = resized(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: quality) else {
            throw PhotoStoreError.encodingFailed
        }
        return (data, resized.size)
    }
}
