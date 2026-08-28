import Foundation
import UIKit

/// Bytes that have been committed to storage and are ready to be referenced by
/// a database row.
struct StoredPhoto: Equatable, Sendable {
    var assetIdentifier: String
    var capturedAt: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var pose: PhotoPose

    init(
        assetIdentifier: String,
        capturedAt: Date? = nil,
        pixelWidth: Int,
        pixelHeight: Int,
        pose: PhotoPose = .front
    ) {
        self.assetIdentifier = assetIdentifier
        self.capturedAt = capturedAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.pose = pose
    }
}

/// Which rendition of a stored photo to load.
enum PhotoVariant: Sendable {
    /// Small square-ish rendition for lists, calendar cells and timelines.
    case thumbnail
    /// Display-resolution rendition for hero images and comparisons.
    case full
}

/// Storage for progress photo binaries.
///
/// Deliberately separate from the database. Images are large, change rarely,
/// and — once sync exists — belong in object storage with their own upload
/// lifecycle. Everything above this protocol deals only in `assetIdentifier`
/// strings, so replacing the local implementation with a remote one is a
/// composition-root change and nothing more.
protocol PhotoStore: Sendable {
    /// Writes an image and returns the reference to persist.
    /// - Parameter capturedAt: original capture date when known.
    func store(_ image: UIImage, capturedAt: Date?, pose: PhotoPose) async throws -> StoredPhoto

    /// Loads a rendition, or `nil` when the asset is missing.
    func image(for assetIdentifier: String, variant: PhotoVariant) async -> UIImage?

    /// Removes both renditions. Missing assets are not an error — deletion
    /// must be idempotent so a retried cleanup cannot fail.
    func remove(assetIdentifier: String) async

    /// Deletes any stored binary not referenced by `referencedIdentifiers`.
    /// Returns how many files were removed.
    @discardableResult
    func removeOrphans(keeping referencedIdentifiers: Set<String>) async -> Int
}

enum PhotoStoreError: LocalizedError {
    case encodingFailed
    case writeFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "That photo could not be prepared for saving."
        case .writeFailed:
            "That photo could not be saved to this device."
        }
    }
}
