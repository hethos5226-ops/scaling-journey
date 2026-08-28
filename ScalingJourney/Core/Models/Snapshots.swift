import Foundation

/// An immutable, `Sendable` view of a `WeightEntry`.
///
/// Everything above the persistence layer — view models, charts, statistics,
/// the calendar — works with snapshots rather than SwiftData models. That
/// keeps the UI off the model actor, makes the statistics layer testable with
/// plain literals, and means a future backend can produce the same values
/// without a database round-trip.
struct WeightEntrySnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var measuredAt: Date
    var weightKilograms: Double
    var note: String?
    var photo: PhotoSnapshot?
    var source: EntrySource

    init(
        id: UUID = UUID(),
        measuredAt: Date,
        weightKilograms: Double,
        note: String? = nil,
        photo: PhotoSnapshot? = nil,
        source: EntrySource = .manual
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.weightKilograms = weightKilograms
        self.note = note
        self.photo = photo
        self.source = source
    }

    var hasPhoto: Bool { photo != nil }

    var hasNote: Bool {
        guard let note else { return false }
        return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct PhotoSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var assetIdentifier: String
    var capturedAt: Date?
    var aspectRatio: Double
    var pose: PhotoPose

    init(
        id: UUID = UUID(),
        assetIdentifier: String,
        capturedAt: Date? = nil,
        aspectRatio: Double = 3.0 / 4.0,
        pose: PhotoPose = .front
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.capturedAt = capturedAt
        self.aspectRatio = aspectRatio
        self.pose = pose
    }
}

/// Snapshot of the signed-in user's preferences and goals.
struct ProfileSnapshot: Hashable, Sendable {
    var accountIdentifier: String
    var displayName: String?
    var preferredUnit: MassUnit
    var goalWeightKilograms: Double?
    var startingWeightKilogramsOverride: Double?

    init(
        accountIdentifier: String,
        displayName: String? = nil,
        preferredUnit: MassUnit = .kilograms,
        goalWeightKilograms: Double? = nil,
        startingWeightKilogramsOverride: Double? = nil
    ) {
        self.accountIdentifier = accountIdentifier
        self.displayName = displayName
        self.preferredUnit = preferredUnit
        self.goalWeightKilograms = goalWeightKilograms
        self.startingWeightKilogramsOverride = startingWeightKilogramsOverride
    }
}

// MARK: - Model conversion

extension WeightEntry {
    func snapshot() -> WeightEntrySnapshot {
        WeightEntrySnapshot(
            id: id,
            measuredAt: measuredAt,
            weightKilograms: weightKilograms,
            note: note,
            photo: primaryPhoto?.snapshot(),
            source: source
        )
    }
}

extension ProgressPhoto {
    func snapshot() -> PhotoSnapshot {
        PhotoSnapshot(
            id: id,
            assetIdentifier: assetIdentifier,
            capturedAt: capturedAt,
            aspectRatio: aspectRatio,
            pose: pose
        )
    }
}

extension UserProfile {
    func snapshot() -> ProfileSnapshot {
        ProfileSnapshot(
            accountIdentifier: accountIdentifier,
            displayName: displayName,
            preferredUnit: preferredUnit,
            goalWeightKilograms: goalWeightKilograms,
            startingWeightKilogramsOverride: startingWeightKilogramsOverride
        )
    }
}
