import Foundation
import UIKit

/// Stores progress photos as JPEG files in the app container.
///
/// Layout, under Application Support:
/// ```
/// ProgressPhotos/
///   <uuid>.jpg        full-size rendition
///   <uuid>_thumb.jpg  thumbnail rendition
/// ```
///
/// ### Why files and not the database
/// Binaries here are hundreds of kilobytes each. Keeping them out of SwiftData
/// keeps the store small and fast to query, and gives the future sync engine a
/// natural split: rows go to the API, files go to object storage.
///
/// ### Privacy
/// The directory is marked as excluded from iCloud/iTunes backup by default:
/// these are unusually personal images and they should not silently leave the
/// device before the user has opted into sync. It is also protected with
/// `.completeUntilFirstUserAuthentication`, so the files are unreadable while
/// the device is locked and has not been unlocked since boot.
actor FilePhotoStore: PhotoStore {
    private let directory: URL
    private let fileManager: FileManager

    /// Decoded thumbnails, so scrolling a long list does not re-decode JPEGs.
    /// `NSCache` evicts automatically under memory pressure.
    private let thumbnailCache = NSCache<NSString, UIImage>()

    init(directoryName: String = "ProgressPhotos", fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = URL.applicationSupportDirectory.appending(path: directoryName, directoryHint: .isDirectory)
        thumbnailCache.countLimit = 200
    }

    // MARK: PhotoStore

    func store(_ image: UIImage, capturedAt: Date?, pose: PhotoPose) async throws -> StoredPhoto {
        try prepareDirectory()

        let identifier = UUID().uuidString
        let full = try ImageProcessing.encode(image, variant: .full)
        let thumbnail = try ImageProcessing.encode(image, variant: .thumbnail)

        do {
            try write(full.data, to: url(for: identifier, variant: .full))
            try write(thumbnail.data, to: url(for: identifier, variant: .thumbnail))
        } catch {
            // Never leave half a photo behind: if the second write fails, the
            // first file would be an orphan pointing at nothing.
            await remove(assetIdentifier: identifier)
            throw PhotoStoreError.writeFailed(underlying: String(describing: error))
        }

        return StoredPhoto(
            assetIdentifier: identifier,
            capturedAt: capturedAt,
            pixelWidth: Int(full.pixelSize.width),
            pixelHeight: Int(full.pixelSize.height),
            pose: pose
        )
    }

    func image(for assetIdentifier: String, variant: PhotoVariant) async -> UIImage? {
        if variant == .thumbnail, let cached = thumbnailCache.object(forKey: assetIdentifier as NSString) {
            return cached
        }

        let location = url(for: assetIdentifier, variant: variant)
        guard let data = try? Data(contentsOf: location, options: .mappedIfSafe),
              let image = UIImage(data: data)
        else {
            // A thumbnail can legitimately be absent for an asset written by an
            // older build; fall back to the full rendition rather than showing
            // a blank tile.
            if variant == .thumbnail {
                return await self.image(for: assetIdentifier, variant: .full)
            }
            return nil
        }

        if variant == .thumbnail {
            thumbnailCache.setObject(image, forKey: assetIdentifier as NSString)
        }
        return image
    }

    func remove(assetIdentifier: String) async {
        thumbnailCache.removeObject(forKey: assetIdentifier as NSString)
        for variant in [PhotoVariant.full, .thumbnail] {
            try? fileManager.removeItem(at: url(for: assetIdentifier, variant: variant))
        }
    }

    @discardableResult
    func removeOrphans(keeping referencedIdentifiers: Set<String>) async -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return 0 }

        var removed = 0
        for file in contents {
            let identifier = Self.assetIdentifier(fromFileName: file.lastPathComponent)
            guard let identifier, !referencedIdentifiers.contains(identifier) else { continue }
            try? fileManager.removeItem(at: file)
            removed += 1
        }

        if removed > 0 {
            AppLog.photos.info("Removed \(removed, privacy: .public) orphaned photo file(s)")
        }
        return removed
    }

    // MARK: Private

    private func url(for identifier: String, variant: PhotoVariant) -> URL {
        let suffix = variant == .full ? ".jpg" : "_thumb.jpg"
        return directory.appending(path: identifier + suffix)
    }

    /// Maps `abc_thumb.jpg` and `abc.jpg` back to `abc`.
    private static func assetIdentifier(fromFileName name: String) -> String? {
        guard name.hasSuffix(".jpg") else { return nil }
        var base = String(name.dropLast(4))
        if base.hasSuffix("_thumb") { base = String(base.dropLast(6)) }
        return base.isEmpty ? nil : base
    }

    private func prepareDirectory() throws {
        guard !fileManager.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var mutable = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutable.setResourceValues(values)
    }

    private func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
