import XCTest
@testable import ScalingJourney

final class ProgressStatisticsTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ daysAgo: Int, from reference: Date = ProgressStatisticsTests.reference) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: reference)!
    }

    private static let reference = Date(timeIntervalSince1970: 1_756_000_000)

    private func entry(_ daysAgo: Int, _ kilograms: Double, hasPhoto: Bool = false, note: String? = nil) -> WeightEntrySnapshot {
        WeightEntrySnapshot(
            measuredAt: date(daysAgo),
            weightKilograms: kilograms,
            note: note,
            photo: hasPhoto ? PhotoSnapshot(assetIdentifier: "asset-\(daysAgo)") : nil
        )
    }

    // MARK: Empty

    func testEmptyStatisticsExposeNothing() {
        let statistics = ProgressStatistics(entries: [])
        XCTAssertTrue(statistics.isEmpty)
        XCTAssertNil(statistics.currentWeightKilograms)
        XCTAssertNil(statistics.changeSincePrevious)
        XCTAssertNil(statistics.changeSinceStart)
        XCTAssertNil(statistics.goalProgress)
        XCTAssertFalse(statistics.hasReachedGoal)
    }

    // MARK: Ordering

    /// Callers must not have to pre-sort; the calendar and a future sync engine
    /// both hand over entries in arbitrary order.
    func testUnsortedInputIsSortedOldestFirst() {
        let statistics = ProgressStatistics(entries: [entry(0, 80), entry(10, 85), entry(5, 82)])
        XCTAssertEqual(statistics.entries.map(\.weightKilograms), [85, 82, 80])
        XCTAssertEqual(statistics.latest?.weightKilograms, 80)
        XCTAssertEqual(statistics.starting?.weightKilograms, 85)
    }

    // MARK: Changes

    func testChangeSincePreviousUsesTheTwoMostRecentEntries() {
        let statistics = ProgressStatistics(entries: [entry(10, 85), entry(5, 82), entry(0, 80.5)])
        XCTAssertEqual(statistics.changeSincePrevious!, -1.5, accuracy: 0.0001)
    }

    func testChangeSincePreviousIsNilWithASingleEntry() {
        XCTAssertNil(ProgressStatistics(entries: [entry(0, 80)]).changeSincePrevious)
    }

    func testChangeSinceStartUsesTheEarliestEntry() {
        let statistics = ProgressStatistics(entries: [entry(10, 85), entry(5, 82), entry(0, 80.5)])
        XCTAssertEqual(statistics.changeSinceStart!, -4.5, accuracy: 0.0001)
    }

    /// A CSV import can begin mid-journey, so the user can pin a baseline that
    /// is earlier than any entry in the database.
    func testStartingWeightOverrideReplacesTheEarliestEntry() {
        let statistics = ProgressStatistics(
            entries: [entry(10, 85), entry(0, 80)],
            startingWeightOverride: 92
        )
        XCTAssertEqual(statistics.startingWeightKilograms!, 92, accuracy: 0.0001)
        XCTAssertEqual(statistics.changeSinceStart!, -12, accuracy: 0.0001)
    }

    // MARK: Extremes

    func testHighestAndLowestScanTheWholeSeries() {
        let statistics = ProgressStatistics(entries: [entry(10, 85), entry(7, 88.4), entry(3, 79.1), entry(0, 80)])
        XCTAssertEqual(statistics.highest?.weightKilograms, 88.4)
        XCTAssertEqual(statistics.lowest?.weightKilograms, 79.1)
    }

    // MARK: Goal

    func testGoalProgressForWeightLoss() {
        let statistics = ProgressStatistics(entries: [entry(10, 90), entry(0, 85)], goalWeightKilograms: 80)
        // Half of a 10 kg journey.
        XCTAssertEqual(statistics.goalProgress!, 0.5, accuracy: 0.0001)
    }

    func testGoalProgressForWeightGain() {
        let statistics = ProgressStatistics(entries: [entry(10, 60), entry(0, 63)], goalWeightKilograms: 70)
        XCTAssertEqual(statistics.goalProgress!, 0.3, accuracy: 0.0001)
    }

    /// Moving the wrong way must not produce a negative bar, and overshooting
    /// must not produce one past the end.
    func testGoalProgressIsClampedToZeroAndOne() {
        let backwards = ProgressStatistics(entries: [entry(10, 90), entry(0, 95)], goalWeightKilograms: 80)
        XCTAssertEqual(backwards.goalProgress!, 0, accuracy: 0.0001)

        let overshoot = ProgressStatistics(entries: [entry(10, 90), entry(0, 75)], goalWeightKilograms: 80)
        XCTAssertEqual(overshoot.goalProgress!, 1, accuracy: 0.0001)
    }

    /// With the goal already at the starting weight there is no journey to
    /// measure, and any bar we drew would be a lie in one direction or the other.
    func testGoalProgressIsNilWhenGoalEqualsStart() {
        let statistics = ProgressStatistics(entries: [entry(10, 80), entry(0, 79)], goalWeightKilograms: 80)
        XCTAssertNil(statistics.goalProgress)
    }

    func testHasReachedGoalWorksInBothDirections() {
        let losing = ProgressStatistics(entries: [entry(10, 90), entry(0, 79.5)], goalWeightKilograms: 80)
        XCTAssertTrue(losing.hasReachedGoal)

        let stillLosing = ProgressStatistics(entries: [entry(10, 90), entry(0, 82)], goalWeightKilograms: 80)
        XCTAssertFalse(stillLosing.hasReachedGoal)

        let gaining = ProgressStatistics(entries: [entry(10, 60), entry(0, 70.2)], goalWeightKilograms: 70)
        XCTAssertTrue(gaining.hasReachedGoal)
    }

    func testRemainingToGoalIsSigned() {
        let losing = ProgressStatistics(entries: [entry(0, 85)], goalWeightKilograms: 80)
        XCTAssertEqual(losing.remainingToGoal!, -5, accuracy: 0.0001)

        let gaining = ProgressStatistics(entries: [entry(0, 65)], goalWeightKilograms: 70)
        XCTAssertEqual(gaining.remainingToGoal!, 5, accuracy: 0.0001)
    }

    // MARK: Moving average

    func testMovingAverageOnlyIncludesEntriesInsideTheWindow() {
        let statistics = ProgressStatistics(entries: [
            entry(30, 100),  // outside a 7-day window
            entry(5, 80),
            entry(2, 82),
            entry(0, 84),
        ])
        XCTAssertEqual(statistics.movingAverage(days: 7, endingAt: Self.reference)!, 82, accuracy: 0.0001)
    }

    func testMovingAverageIsNilWhenTheWindowIsEmpty() {
        let statistics = ProgressStatistics(entries: [entry(60, 100)])
        XCTAssertNil(statistics.movingAverage(days: 7, endingAt: Self.reference))
    }

    // MARK: Photos and recency

    func testLatestPhotoEntryIgnoresNewerPhotolessEntries() {
        let statistics = ProgressStatistics(entries: [
            entry(10, 85, hasPhoto: true),
            entry(5, 83, hasPhoto: true),
            entry(0, 82),
        ])
        XCTAssertEqual(statistics.latestPhotoEntry?.weightKilograms, 83)
    }

    func testLatestPhotoEntryIsNilWithNoPhotos() {
        XCTAssertNil(ProgressStatistics(entries: [entry(0, 80)]).latestPhotoEntry)
    }

    func testMostRecentReturnsNewestFirstAndRespectsTheLimit() {
        let statistics = ProgressStatistics(entries: [entry(10, 85), entry(5, 83), entry(2, 82), entry(0, 81)])
        XCTAssertEqual(statistics.mostRecent(2).map(\.weightKilograms), [81, 82])
        XCTAssertEqual(statistics.mostRecent(99).count, 4)
    }
}

// MARK: - Snapshot helpers

final class WeightEntrySnapshotTests: XCTestCase {
    /// Whitespace-only notes must not light up the "has a note" indicator in
    /// the calendar or the entry row.
    func testWhitespaceOnlyNoteDoesNotCount() {
        let blank = WeightEntrySnapshot(measuredAt: .now, weightKilograms: 80, note: "   \n ")
        XCTAssertFalse(blank.hasNote)

        let real = WeightEntrySnapshot(measuredAt: .now, weightKilograms: 80, note: "Felt strong")
        XCTAssertTrue(real.hasNote)

        let none = WeightEntrySnapshot(measuredAt: .now, weightKilograms: 80)
        XCTAssertFalse(none.hasNote)
    }
}

// MARK: - Range filter

final class DateRangeFilterTests: XCTestCase {
    private static let reference = Date(timeIntervalSince1970: 1_756_000_000)

    private func entry(daysAgo: Int) -> WeightEntrySnapshot {
        WeightEntrySnapshot(
            measuredAt: Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: Self.reference)!,
            weightKilograms: 80
        )
    }

    func testWeekFilterKeepsOnlyRecentEntries() {
        let entries = [entry(daysAgo: 40), entry(daysAgo: 8), entry(daysAgo: 3), entry(daysAgo: 0)]
        let filtered = DateRangeFilter.week.filter(entries, relativeTo: Self.reference)
        XCTAssertEqual(filtered.count, 2)
    }

    func testAllTimeReturnsEverything() {
        let entries = [entry(daysAgo: 4000), entry(daysAgo: 0)]
        XCTAssertEqual(DateRangeFilter.allTime.filter(entries, relativeTo: Self.reference).count, 2)
    }

    func testEveryFilterHasADistinctShortTitle() {
        let titles = DateRangeFilter.allCases.map(\.shortTitle)
        XCTAssertEqual(Set(titles).count, titles.count)
    }
}
