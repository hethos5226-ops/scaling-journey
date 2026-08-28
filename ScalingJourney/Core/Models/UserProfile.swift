import Foundation
import SwiftData

/// Per-account preferences and goals.
///
/// Exactly one row exists per signed-in account; `ProfileRepository` guarantees
/// that. Preferences live in the database rather than `UserDefaults` because
/// they must travel with the account to a new device.
@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID

    /// Ties the profile to an `Account`. For the device-local account this is
    /// a stable generated id; for a real backend it is the server's user id.
    var accountIdentifier: String

    var displayName: String?

    /// Preferred display unit. Storage stays in kilograms regardless.
    var preferredUnitRawValue: String

    /// Target weight in kilograms, `nil` when the user has not set a goal.
    var goalWeightKilograms: Double?

    /// Overrides the first logged entry as the "starting weight" baseline.
    /// Useful after a CSV import that begins mid-journey.
    var startingWeightKilogramsOverride: Double?

    // MARK: Sync metadata

    var createdAt: Date
    var updatedAt: Date
    var remoteID: String?
    var syncStateRawValue: String

    init(
        id: UUID = UUID(),
        accountIdentifier: String,
        displayName: String? = nil,
        preferredUnit: MassUnit = .kilograms,
        goalWeightKilograms: Double? = nil,
        startingWeightKilogramsOverride: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.accountIdentifier = accountIdentifier
        self.displayName = displayName
        self.preferredUnitRawValue = preferredUnit.rawValue
        self.goalWeightKilograms = goalWeightKilograms
        self.startingWeightKilogramsOverride = startingWeightKilogramsOverride
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteID = nil
        self.syncStateRawValue = SyncState.localOnly.rawValue
    }
}

extension UserProfile {
    var preferredUnit: MassUnit {
        get { MassUnit(rawValue: preferredUnitRawValue) ?? .kilograms }
        set { preferredUnitRawValue = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRawValue) ?? .localOnly }
        set { syncStateRawValue = newValue.rawValue }
    }

    func touch(now: Date = .now) {
        updatedAt = now
        if syncState == .synced { syncState = .pendingUpload }
    }
}
