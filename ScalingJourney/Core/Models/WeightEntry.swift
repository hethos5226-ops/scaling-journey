import Foundation
import SwiftData

/// One weight reading, optionally with photos and a note.
///
/// ## Storage rules
/// - Weight is stored in **kilograms**, always. Display units are a preference.
/// - Photos are **never** stored in this database. `ProgressPhoto` holds an
///   identifier that resolves to a file on disk (and later, an object in cloud
///   storage) via `PhotoStore`.
@Model
final class WeightEntry {
    /// Stable identity that survives sync. Generated on device, never reused.
    @Attribute(.unique) var id: UUID

    /// The moment the reading applies to — user editable, and what every
    /// chart, calendar cell and timeline row sorts by.
    var measuredAt: Date

    var weightKilograms: Double

    var note: String?

    /// Photos attached to this reading. Phase 1 writes at most one, but the
    /// relationship is to-many so same-pose sets (front/side/back) drop in
    /// later without a migration.
    @Relationship(deleteRule: .cascade, inverse: \ProgressPhoto.entry)
    var photos: [ProgressPhoto]

    // MARK: Provenance

    var sourceRawValue: String
    /// The originating system's own identifier, used to keep imports idempotent.
    var externalIdentifier: String?

    // MARK: Sync metadata

    var createdAt: Date
    var updatedAt: Date
    /// Server-assigned id, `nil` until the record has been uploaded once.
    var remoteID: String?
    var syncStateRawValue: String
    /// Soft delete. Rows are tombstoned rather than removed so a delete made
    /// on one device can propagate instead of being resurrected by a peer.
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        measuredAt: Date,
        weightKilograms: Double,
        note: String? = nil,
        photos: [ProgressPhoto] = [],
        source: EntrySource = .manual,
        externalIdentifier: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.weightKilograms = weightKilograms
        self.note = note
        self.photos = photos
        self.sourceRawValue = source.rawValue
        self.externalIdentifier = externalIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteID = nil
        self.syncStateRawValue = SyncState.localOnly.rawValue
        self.deletedAt = nil
    }
}

// MARK: - Typed accessors
//
// SwiftData indexes and predicates are far more reliable against primitive
// stored properties than against enums, so the enums are stored as raw strings
// and surfaced through these computed properties.

extension WeightEntry {
    var source: EntrySource {
        get { EntrySource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRawValue) ?? .localOnly }
        set { syncStateRawValue = newValue.rawValue }
    }

    var isDeleted: Bool { deletedAt != nil }

    /// The photo shown wherever a single image represents the entry.
    var primaryPhoto: ProgressPhoto? {
        photos.sorted { $0.createdAt < $1.createdAt }.first
    }

    /// Call after any user-facing mutation so sync can order writes correctly.
    func touch(now: Date = .now) {
        updatedAt = now
        if syncState == .synced { syncState = .pendingUpload }
    }
}
