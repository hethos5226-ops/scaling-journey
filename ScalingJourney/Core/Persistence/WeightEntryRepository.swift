import Foundation
import SwiftData

/// Read/write access to weight entries.
///
/// A protocol rather than direct SwiftData use in view models so that:
/// - tests can substitute an in-memory or stub implementation;
/// - a future cloud-backed repository can be swapped in without touching the UI.
@MainActor
protocol WeightEntryRepository {
    /// All non-deleted entries, oldest first.
    func fetchAll() throws -> [WeightEntrySnapshot]

    /// Creates an entry, optionally attaching an already-stored photo.
    @discardableResult
    func create(_ draft: WeightEntryDraft) throws -> WeightEntrySnapshot

    /// Applies a draft to an existing entry.
    @discardableResult
    func update(id: UUID, with draft: WeightEntryDraft) throws -> WeightEntrySnapshot

    /// Soft-deletes an entry so the deletion can propagate to other devices.
    /// Returns the asset identifiers whose binaries are now orphaned, for the
    /// caller to remove from `PhotoStore`.
    @discardableResult
    func delete(id: UUID) throws -> [String]

    /// Entries whose `measuredAt` falls on the given day, oldest first.
    func entries(on day: Date, calendar: Calendar) throws -> [WeightEntrySnapshot]
}

/// The user-editable fields of an entry, used for both create and update.
///
/// Photos are referenced by `StoredPhoto` because the bytes are written to
/// `PhotoStore` *before* the database row is created — that ordering means a
/// crash can leave an orphaned file (cheap to clean up) rather than a row
/// pointing at an image that does not exist (a broken UI).
struct WeightEntryDraft: Equatable, Sendable {
    var measuredAt: Date
    var weightKilograms: Double
    var note: String?
    var photo: StoredPhoto?
    /// When true, an update removes any existing photo. Distinct from
    /// `photo == nil`, which means "leave the current photo alone".
    var removesExistingPhoto: Bool
    var source: EntrySource
    var externalIdentifier: String?

    init(
        measuredAt: Date,
        weightKilograms: Double,
        note: String? = nil,
        photo: StoredPhoto? = nil,
        removesExistingPhoto: Bool = false,
        source: EntrySource = .manual,
        externalIdentifier: String? = nil
    ) {
        self.measuredAt = measuredAt
        self.weightKilograms = weightKilograms
        self.note = note
        self.photo = photo
        self.removesExistingPhoto = removesExistingPhoto
        self.source = source
        self.externalIdentifier = externalIdentifier
    }
}

// MARK: - SwiftData implementation

@MainActor
final class SwiftDataWeightEntryRepository: WeightEntryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [WeightEntrySnapshot] {
        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.measuredAt, order: .forward)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.photos]
        return try context.fetch(descriptor).map { $0.snapshot() }
    }

    @discardableResult
    func create(_ draft: WeightEntryDraft) throws -> WeightEntrySnapshot {
        let entry = WeightEntry(
            measuredAt: draft.measuredAt,
            weightKilograms: draft.weightKilograms,
            note: draft.normalisedNote,
            source: draft.source,
            externalIdentifier: draft.externalIdentifier
        )
        context.insert(entry)

        if let stored = draft.photo {
            let photo = makePhoto(from: stored)
            context.insert(photo)
            photo.entry = entry
        }

        try context.save()
        return entry.snapshot()
    }

    @discardableResult
    func update(id: UUID, with draft: WeightEntryDraft) throws -> WeightEntrySnapshot {
        guard let entry = try entry(withID: id) else {
            throw RepositoryError.entryNotFound(id)
        }

        entry.measuredAt = draft.measuredAt
        entry.weightKilograms = draft.weightKilograms
        entry.note = draft.normalisedNote

        if draft.removesExistingPhoto || draft.photo != nil {
            for existing in entry.photos {
                context.delete(existing)
            }
            entry.photos = []
        }

        if let stored = draft.photo {
            let photo = makePhoto(from: stored)
            context.insert(photo)
            photo.entry = entry
        }

        entry.touch()
        try context.save()
        return entry.snapshot()
    }

    @discardableResult
    func delete(id: UUID) throws -> [String] {
        guard let entry = try entry(withID: id) else {
            throw RepositoryError.entryNotFound(id)
        }

        let orphanedAssets = entry.photos.map(\.assetIdentifier)
        let now = Date.now
        entry.deletedAt = now
        for photo in entry.photos {
            photo.deletedAt = now
        }
        entry.touch(now: now)
        try context.save()
        return orphanedAssets
    }

    func entries(on day: Date, calendar: Calendar = .current) throws -> [WeightEntrySnapshot] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate {
                $0.deletedAt == nil && $0.measuredAt >= start && $0.measuredAt < end
            },
            sortBy: [SortDescriptor(\.measuredAt, order: .forward)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.photos]
        return try context.fetch(descriptor).map { $0.snapshot() }
    }

    // MARK: Private

    private func entry(withID id: UUID) throws -> WeightEntry? {
        var descriptor = FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func makePhoto(from stored: StoredPhoto) -> ProgressPhoto {
        ProgressPhoto(
            assetIdentifier: stored.assetIdentifier,
            capturedAt: stored.capturedAt,
            pixelWidth: stored.pixelWidth,
            pixelHeight: stored.pixelHeight,
            pose: stored.pose
        )
    }
}

private extension WeightEntryDraft {
    /// Empty and whitespace-only notes are stored as `nil` so "has a note"
    /// checks stay a simple nil test everywhere else.
    var normalisedNote: String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum RepositoryError: LocalizedError, Equatable {
    case entryNotFound(UUID)
    case profileUnavailable

    var errorDescription: String? {
        switch self {
        case .entryNotFound:
            "That entry could no longer be found."
        case .profileUnavailable:
            "Your profile could not be loaded."
        }
    }
}
