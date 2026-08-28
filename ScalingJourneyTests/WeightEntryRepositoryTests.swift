import SwiftData
import XCTest
@testable import ScalingJourney

/// Exercises the SwiftData repository against a real in-memory container, so
/// the predicates, relationships and cascade rules are genuinely tested rather
/// than mocked away.
@MainActor
final class WeightEntryRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataWeightEntryRepository!

    /// Built per test rather than in `setUpWithError`.
    ///
    /// `XCTestCase`'s setup hooks are non-isolated, so overriding them from a
    /// `@MainActor` test case means overriding a non-isolated method with an
    /// isolated one. Calling an ordinary helper from inside each (already
    /// main-actor) test body sidesteps that entirely, and each test still gets
    /// a clean store.
    private func makeRepository() throws {
        container = try ModelContainerFactory.makeInMemory()
        repository = SwiftDataWeightEntryRepository(context: container.mainContext)
    }

    private func draft(
        daysAgo: Int = 0,
        kilograms: Double = 80,
        note: String? = nil,
        photo: StoredPhoto? = nil
    ) -> WeightEntryDraft {
        WeightEntryDraft(
            measuredAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            weightKilograms: kilograms,
            note: note,
            photo: photo
        )
    }

    private func storedPhoto(_ identifier: String) -> StoredPhoto {
        StoredPhoto(assetIdentifier: identifier, capturedAt: .now, pixelWidth: 1200, pixelHeight: 1600)
    }

    // MARK: Create

    func testCreatePersistsAnEntry() throws {
        try makeRepository()
        try repository.create(draft(kilograms: 81.2))
        let all = try repository.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].weightKilograms, 81.2)
    }

    func testFetchAllReturnsOldestFirst() throws {
        try makeRepository()
        try repository.create(draft(daysAgo: 0, kilograms: 80))
        try repository.create(draft(daysAgo: 10, kilograms: 85))
        try repository.create(draft(daysAgo: 5, kilograms: 82))

        XCTAssertEqual(try repository.fetchAll().map(\.weightKilograms), [85, 82, 80])
    }

    func testCreateAttachesAPhoto() throws {
        try makeRepository()
        let snapshot = try repository.create(draft(photo: storedPhoto("asset-1")))
        XCTAssertEqual(snapshot.photo?.assetIdentifier, "asset-1")
        XCTAssertTrue(try repository.fetchAll()[0].hasPhoto)
    }

    /// Empty and whitespace-only notes collapse to nil so "has a note" stays a
    /// simple check everywhere else in the app.
    func testBlankNotesAreStoredAsNil() throws {
        try makeRepository()
        let blank = try repository.create(draft(note: "   "))
        XCTAssertNil(blank.note)

        let empty = try repository.create(draft(daysAgo: 1, note: ""))
        XCTAssertNil(empty.note)

        let real = try repository.create(draft(daysAgo: 2, note: "  Felt good  "))
        XCTAssertEqual(real.note, "Felt good")
    }

    // MARK: Update

    func testUpdateChangesWeightAndNote() throws {
        try makeRepository()
        let created = try repository.create(draft(kilograms: 80, note: "before"))
        let updated = try repository.update(
            id: created.id,
            with: draft(kilograms: 79.4, note: "after")
        )

        XCTAssertEqual(updated.weightKilograms, 79.4)
        XCTAssertEqual(updated.note, "after")
        XCTAssertEqual(try repository.fetchAll().count, 1, "Update must not create a second row")
    }

    func testUpdateReplacesAnExistingPhoto() throws {
        try makeRepository()
        let created = try repository.create(draft(photo: storedPhoto("old")))
        let updated = try repository.update(id: created.id, with: draft(photo: storedPhoto("new")))
        XCTAssertEqual(updated.photo?.assetIdentifier, "new")
    }

    /// `photo == nil` means "leave it alone"; removal needs the explicit flag,
    /// otherwise editing a note would silently drop the photo.
    func testUpdateWithoutAPhotoKeepsTheExistingOne() throws {
        try makeRepository()
        let created = try repository.create(draft(photo: storedPhoto("keep")))
        let updated = try repository.update(id: created.id, with: draft(note: "just a note"))
        XCTAssertEqual(updated.photo?.assetIdentifier, "keep")
    }

    func testUpdateRemovesThePhotoWhenAsked() throws {
        try makeRepository()
        let created = try repository.create(draft(photo: storedPhoto("drop")))
        var removal = draft()
        removal.removesExistingPhoto = true

        let updated = try repository.update(id: created.id, with: removal)
        XCTAssertNil(updated.photo)
    }

    func testUpdateOfAMissingEntryThrows() throws {
        try makeRepository()
        XCTAssertThrowsError(try repository.update(id: UUID(), with: draft())) { error in
            guard case RepositoryError.entryNotFound = error else {
                return XCTFail("Expected entryNotFound, got \(error)")
            }
        }
    }

    // MARK: Delete

    /// Deletes are tombstones so they can propagate to other devices instead of
    /// being resurrected by a peer that never saw the removal.
    func testDeleteSoftDeletesAndHidesTheEntry() throws {
        try makeRepository()
        let created = try repository.create(draft())
        let orphaned = try repository.delete(id: created.id)

        XCTAssertTrue(orphaned.isEmpty)
        XCTAssertTrue(try repository.fetchAll().isEmpty)

        let tombstones = try container.mainContext.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(tombstones.count, 1)
        XCTAssertNotNil(tombstones[0].deletedAt)
    }

    /// The caller needs the asset ids back so it can delete the files too;
    /// otherwise every deleted entry leaks a photo into the container forever.
    func testDeleteReportsOrphanedPhotoAssets() throws {
        try makeRepository()
        let created = try repository.create(draft(photo: storedPhoto("orphan-me")))
        XCTAssertEqual(try repository.delete(id: created.id), ["orphan-me"])
    }

    func testDeleteOfAMissingEntryThrows() throws {
        try makeRepository()
        XCTAssertThrowsError(try repository.delete(id: UUID()))
    }

    // MARK: Day queries

    func testEntriesOnADayIgnoreOtherDays() throws {
        try makeRepository()
        let today = Date.now
        try repository.create(draft(daysAgo: 0))
        try repository.create(draft(daysAgo: 1))
        try repository.create(draft(daysAgo: 2))

        XCTAssertEqual(try repository.entries(on: today, calendar: .current).count, 1)
    }

    func testEntriesOnADayExcludeDeletedOnes() throws {
        try makeRepository()
        let created = try repository.create(draft(daysAgo: 0))
        try repository.delete(id: created.id)
        XCTAssertTrue(try repository.entries(on: .now, calendar: .current).isEmpty)
    }
}

// MARK: - Profile

@MainActor
final class ProfileRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataProfileRepository!
    private let account = "test-account"

    /// See the note on `WeightEntryRepositoryTests.makeRepository`.
    private func makeRepository() throws {
        container = try ModelContainerFactory.makeInMemory()
        repository = SwiftDataProfileRepository(context: container.mainContext)
    }

    /// Callers must never have to handle a missing profile.
    func testProfileIsCreatedOnFirstAccess() throws {
        try makeRepository()
        let profile = try repository.profile(for: account)
        XCTAssertEqual(profile.accountIdentifier, account)
        XCTAssertNil(profile.goalWeightKilograms)
    }

    func testRepeatedAccessReturnsTheSameProfile() throws {
        try makeRepository()
        _ = try repository.profile(for: account)
        _ = try repository.profile(for: account)

        let stored = try container.mainContext.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(stored.count, 1)
    }

    func testUpdateSetsOnlyTheFieldsProvided() throws {
        try makeRepository()
        _ = try repository.update(account) { $0.goalWeightKilograms = .some(75) }
        let afterUnitChange = try repository.update(account) { $0.preferredUnit = .pounds }

        XCTAssertEqual(afterUnitChange.preferredUnit, .pounds)
        XCTAssertEqual(afterUnitChange.goalWeightKilograms, 75, "Unrelated fields must survive an update")
    }

    /// The double optional exists so a goal can be cleared, not just replaced.
    func testGoalCanBeCleared() throws {
        try makeRepository()
        _ = try repository.update(account) { $0.goalWeightKilograms = .some(75) }
        let cleared = try repository.update(account) { $0.goalWeightKilograms = .some(nil) }
        XCTAssertNil(cleared.goalWeightKilograms)
    }

    func testDefaultUnitFollowsTheDeviceRegion() {
        XCTAssertEqual(SwiftDataProfileRepository.unitMatchingDeviceLocale(Locale(identifier: "en_US")), .pounds)
        XCTAssertEqual(SwiftDataProfileRepository.unitMatchingDeviceLocale(Locale(identifier: "en_GB")), .stones)
        XCTAssertEqual(SwiftDataProfileRepository.unitMatchingDeviceLocale(Locale(identifier: "de_DE")), .kilograms)
        XCTAssertEqual(SwiftDataProfileRepository.unitMatchingDeviceLocale(Locale(identifier: "ja_JP")), .kilograms)
    }
}

private extension SwiftDataProfileRepository {
    /// Test-only shorthand so the intent of each case stays readable.
    @discardableResult
    func update(_ account: String, _ mutate: (inout ProfileEdits) -> Void) throws -> ProfileSnapshot {
        try update(accountIdentifier: account, mutate)
    }
}
