import Foundation
import SwiftData

/// A photo attached to a weight entry.
///
/// This record deliberately stores **no image data**. It holds an
/// `assetIdentifier` that `PhotoStore` resolves to bytes — today a file in the
/// app's Application Support directory, later an object in cloud storage. The
/// database therefore stays small enough to sync cheaply, and swapping storage
/// backends never touches the schema.
@Model
final class ProgressPhoto {
    @Attribute(.unique) var id: UUID

    /// Opaque key understood by `PhotoStore`. Never a file path: paths change
    /// between app launches because the container directory is not stable.
    var assetIdentifier: String

    /// When the photo was actually taken, when we can determine it. For camera
    /// captures this is now; for library picks it comes from the asset's
    /// metadata and is what historical photo matching will key off.
    var capturedAt: Date?

    /// Pixel dimensions of the stored full-size image, used to reserve layout
    /// space before the image has decoded.
    var pixelWidth: Int
    var pixelHeight: Int

    var poseRawValue: String

    var entry: WeightEntry?

    // MARK: Sync metadata

    var createdAt: Date
    var updatedAt: Date
    var remoteID: String?
    /// Set once the binary itself is in cloud storage, which is tracked
    /// separately from the metadata row because the two upload independently.
    var remoteAssetURLString: String?
    var syncStateRawValue: String
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        assetIdentifier: String,
        capturedAt: Date? = nil,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        pose: PhotoPose = .front,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.capturedAt = capturedAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.poseRawValue = pose.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteID = nil
        self.remoteAssetURLString = nil
        self.syncStateRawValue = SyncState.localOnly.rawValue
        self.deletedAt = nil
    }
}

extension ProgressPhoto {
    var pose: PhotoPose {
        get { PhotoPose(rawValue: poseRawValue) ?? .front }
        set { poseRawValue = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRawValue) ?? .localOnly }
        set { syncStateRawValue = newValue.rawValue }
    }

    /// Aspect ratio of the stored image, falling back to 3:4 portrait when the
    /// dimensions were not recorded.
    var aspectRatio: Double {
        guard pixelWidth > 0, pixelHeight > 0 else { return 3.0 / 4.0 }
        return Double(pixelWidth) / Double(pixelHeight)
    }
}

/// Which angle a progress photo was taken from.
///
/// Phase 1 only ever writes `.front`, but same-pose comparison is a planned
/// feature and storing the pose now means existing photos are not stranded
/// without one later.
enum PhotoPose: String, Codable, CaseIterable, Sendable {
    case front
    case side
    case back

    var displayName: String {
        switch self {
        case .front: "Front"
        case .side: "Side"
        case .back: "Back"
        }
    }
}
