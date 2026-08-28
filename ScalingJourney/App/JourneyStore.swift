import Foundation
import Observation

/// The app's single source of UI truth.
///
/// Every screen observes this object rather than querying SwiftData directly.
/// The whole entry list is held in memory, which is the right trade here: a
/// person logging daily for five years has under 2,000 rows of a handful of
/// scalars each. In exchange, every screen recomputes instantly, statistics
/// stay consistent between tabs, and a future sync engine has one place to
/// publish changes into.
@MainActor
@Observable
final class JourneyStore {
    // MARK: Published state

    /// All entries, oldest first.
    private(set) var entries: [WeightEntrySnapshot] = []
    private(set) var profile: ProfileSnapshot?
    private(set) var isLoading = true

    /// Set when an operation fails in a way the user should see. Screens bind
    /// an alert to this and clear it on dismissal.
    var errorMessage: String?

    // MARK: Dependencies

    private let entryRepository: any WeightEntryRepository
    private let profileRepository: any ProfileRepository
    private let photoStore: any PhotoStore
    private let syncEngine: any SyncEngine

    private var accountIdentifier: String?

    init(
        entryRepository: any WeightEntryRepository,
        profileRepository: any ProfileRepository,
        photoStore: any PhotoStore,
        syncEngine: any SyncEngine
    ) {
        self.entryRepository = entryRepository
        self.profileRepository = profileRepository
        self.photoStore = photoStore
        self.syncEngine = syncEngine
    }

    // MARK: Derived state

    var preferredUnit: MassUnit { profile?.preferredUnit ?? .kilograms }

    var formatter: WeightFormatter { WeightFormatter(unit: preferredUnit) }

    var statistics: ProgressStatistics {
        ProgressStatistics(
            entries: entries,
            goalWeightKilograms: profile?.goalWeightKilograms,
            startingWeightOverride: profile?.startingWeightKilogramsOverride
        )
    }

    var hasEntries: Bool { !entries.isEmpty }

    /// Change between `entry` and the entry immediately before it, for rows
    /// that show a per-entry delta. `nil` for the very first entry.
    func changeSincePreviousEntry(for entry: WeightEntrySnapshot) -> Double? {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }), index > 0 else { return nil }
        return entry.weightKilograms - entries[index - 1].weightKilograms
    }

    /// Tint for a change, taking the user's goal direction into account.
    func tint(for change: Double?) -> ChangeTint {
        guard let change else { return .neutral }
        return ChangeTint.forChange(
            change,
            goalKilograms: profile?.goalWeightKilograms,
            currentKilograms: statistics.currentWeightKilograms
        )
    }

    /// Entries recorded on the given calendar day, newest first.
    func entries(on day: Date, calendar: Calendar = .current) -> [WeightEntrySnapshot] {
        Array(
            entries
                .filter { calendar.isDate($0.measuredAt, inSameDayAs: day) }
                .reversed()
        )
    }

    // MARK: Loading

    /// Loads everything for an account. Safe to call again on account change.
    func load(accountIdentifier: String) async {
        self.accountIdentifier = accountIdentifier
        isLoading = true
        defer { isLoading = false }

        do {
            profile = try profileRepository.profile(for: accountIdentifier)
            entries = try entryRepository.fetchAll()
        } catch {
            AppLog.persistence.error("Load failed: \(String(describing: error))")
            errorMessage = "Your journey could not be loaded. Please restart the app."
        }
    }

    /// Re-reads entries from the store, e.g. after a background sync.
    func refreshEntries() async {
        do {
            entries = try entryRepository.fetchAll()
        } catch {
            AppLog.persistence.error("Refresh failed: \(String(describing: error))")
        }
    }

    // MARK: Mutations

    /// Persists a new entry.
    ///
    /// Photo bytes are written *before* the database row, so a failure part
    /// way through leaves at most an unreferenced file (cleaned up by
    /// `removeOrphanedPhotos`) rather than a row pointing at a missing image.
    @discardableResult
    func createEntry(_ draft: WeightEntryDraft) async -> Bool {
        do {
            try entryRepository.create(draft)
            await refreshEntries()
            await syncEngine.scheduleUpload()
            return true
        } catch {
            AppLog.persistence.error("Create entry failed: \(String(describing: error))")
            // The photo is already on disk at this point; drop it so it does
            // not linger unreferenced.
            if let identifier = draft.photo?.assetIdentifier {
                await photoStore.remove(assetIdentifier: identifier)
            }
            errorMessage = "That entry could not be saved. Please try again."
            return false
        }
    }

    @discardableResult
    func updateEntry(id: UUID, with draft: WeightEntryDraft) async -> Bool {
        do {
            try entryRepository.update(id: id, with: draft)
            await refreshEntries()
            await syncEngine.scheduleUpload()
            return true
        } catch {
            AppLog.persistence.error("Update entry failed: \(String(describing: error))")
            errorMessage = "That entry could not be updated. Please try again."
            return false
        }
    }

    func deleteEntry(id: UUID) async {
        do {
            let orphanedAssets = try entryRepository.delete(id: id)
            for identifier in orphanedAssets {
                await photoStore.remove(assetIdentifier: identifier)
            }
            await refreshEntries()
            await syncEngine.scheduleUpload()
        } catch {
            AppLog.persistence.error("Delete entry failed: \(String(describing: error))")
            errorMessage = "That entry could not be deleted. Please try again."
        }
    }

    // MARK: Profile

    func setPreferredUnit(_ unit: MassUnit) async {
        await updateProfile { $0.preferredUnit = unit }
    }

    /// Sets or clears the goal. Passing `nil` removes it.
    func setGoalWeight(kilograms: Double?) async {
        await updateProfile { $0.goalWeightKilograms = .some(kilograms) }
    }

    func setStartingWeightOverride(kilograms: Double?) async {
        await updateProfile { $0.startingWeightKilogramsOverride = .some(kilograms) }
    }

    private func updateProfile(_ mutate: @escaping (inout ProfileEdits) -> Void) async {
        guard let accountIdentifier else { return }
        do {
            profile = try profileRepository.update(accountIdentifier: accountIdentifier, mutate)
            await syncEngine.scheduleUpload()
        } catch {
            AppLog.persistence.error("Profile update failed: \(String(describing: error))")
            errorMessage = "That setting could not be saved."
        }
    }

    // MARK: Maintenance

    /// Deletes photo files that no live entry references.
    ///
    /// Runs at launch. Orphans can only appear after an interrupted save, so
    /// this is normally a no-op, but it keeps the container from growing
    /// invisibly over years of use.
    func removeOrphanedPhotos() async {
        let referenced = Set(entries.compactMap { $0.photo?.assetIdentifier })
        await photoStore.removeOrphans(keeping: referenced)
    }
}
