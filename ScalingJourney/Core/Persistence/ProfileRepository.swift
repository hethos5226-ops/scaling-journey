import Foundation
import SwiftData

/// Access to the signed-in account's preferences and goals.
@MainActor
protocol ProfileRepository {
    /// Returns the profile for the account, creating it on first access so
    /// callers never have to deal with a missing profile.
    func profile(for accountIdentifier: String) throws -> ProfileSnapshot

    @discardableResult
    func update(accountIdentifier: String, _ mutate: (inout ProfileEdits) -> Void) throws -> ProfileSnapshot
}

/// The editable subset of a profile.
///
/// `Double??` on the optional weights is deliberate: the outer optional means
/// "not being changed", the inner one means "set to no value". That lets a
/// caller clear a goal without a separate `clearGoal()` API.
struct ProfileEdits: Equatable, Sendable {
    var displayName: String??
    var preferredUnit: MassUnit?
    var goalWeightKilograms: Double??
    var startingWeightKilogramsOverride: Double??

    init() {
        self.displayName = nil
        self.preferredUnit = nil
        self.goalWeightKilograms = nil
        self.startingWeightKilogramsOverride = nil
    }
}

@MainActor
final class SwiftDataProfileRepository: ProfileRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func profile(for accountIdentifier: String) throws -> ProfileSnapshot {
        try existingProfile(for: accountIdentifier)?.snapshot()
            ?? createProfile(for: accountIdentifier).snapshot()
    }

    @discardableResult
    func update(accountIdentifier: String, _ mutate: (inout ProfileEdits) -> Void) throws -> ProfileSnapshot {
        let profile = try existingProfile(for: accountIdentifier) ?? createProfile(for: accountIdentifier)

        var edits = ProfileEdits()
        mutate(&edits)

        if let displayName = edits.displayName { profile.displayName = displayName }
        if let unit = edits.preferredUnit { profile.preferredUnit = unit }
        if let goal = edits.goalWeightKilograms { profile.goalWeightKilograms = goal }
        if let start = edits.startingWeightKilogramsOverride {
            profile.startingWeightKilogramsOverride = start
        }

        profile.touch()
        try context.save()
        return profile.snapshot()
    }

    // MARK: Private

    private func existingProfile(for accountIdentifier: String) throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.accountIdentifier == accountIdentifier }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    private func createProfile(for accountIdentifier: String) -> UserProfile {
        let profile = UserProfile(
            accountIdentifier: accountIdentifier,
            preferredUnit: Self.unitMatchingDeviceLocale()
        )
        context.insert(profile)
        // Saved lazily by the next `update`; failing to persist a freshly
        // created default profile is not worth surfacing to the user.
        try? context.save()
        return profile
    }

    /// Sensible first-run default: pounds in the US, stones in the UK,
    /// kilograms everywhere else.
    static func unitMatchingDeviceLocale(_ locale: Locale = .current) -> MassUnit {
        switch locale.region?.identifier {
        case "US", "LR", "MM": .pounds
        case "GB", "IE": .stones
        default: .kilograms
        }
    }
}
