import Foundation

/// Every headline number the app shows, derived in one place from a list of
/// entries.
///
/// This type is intentionally free of SwiftData, SwiftUI and UIKit: it takes
/// value types in and gives value types out, so it is fully unit-testable and
/// can be reused unchanged by widgets or a future watch app.
///
/// The initialiser assumes nothing about ordering — it sorts defensively.
struct ProgressStatistics: Equatable, Sendable {
    /// Entries sorted oldest first.
    let entries: [WeightEntrySnapshot]

    let latest: WeightEntrySnapshot?
    let previous: WeightEntrySnapshot?
    let starting: WeightEntrySnapshot?
    let highest: WeightEntrySnapshot?
    let lowest: WeightEntrySnapshot?

    /// Overrides the first entry as the baseline, when the user set one.
    let startingWeightOverride: Double?
    let goalWeightKilograms: Double?

    init(
        entries: [WeightEntrySnapshot],
        goalWeightKilograms: Double? = nil,
        startingWeightOverride: Double? = nil
    ) {
        let sorted = entries.sorted { $0.measuredAt < $1.measuredAt }
        self.entries = sorted
        self.latest = sorted.last
        self.previous = sorted.count >= 2 ? sorted[sorted.count - 2] : nil
        self.starting = sorted.first
        self.highest = sorted.max { $0.weightKilograms < $1.weightKilograms }
        self.lowest = sorted.min { $0.weightKilograms < $1.weightKilograms }
        self.goalWeightKilograms = goalWeightKilograms
        self.startingWeightOverride = startingWeightOverride
    }

    var isEmpty: Bool { entries.isEmpty }

    var currentWeightKilograms: Double? { latest?.weightKilograms }

    /// The baseline used for "total change" and goal progress: the explicit
    /// override when set, otherwise the earliest recorded entry.
    var startingWeightKilograms: Double? {
        startingWeightOverride ?? starting?.weightKilograms
    }

    /// Change between the two most recent entries. `nil` with fewer than two.
    var changeSincePrevious: Double? {
        guard let latest, let previous else { return nil }
        return latest.weightKilograms - previous.weightKilograms
    }

    /// Change from the baseline to the latest reading.
    var changeSinceStart: Double? {
        guard let latest, let startingWeightKilograms else { return nil }
        return latest.weightKilograms - startingWeightKilograms
    }

    /// Signed distance still to travel to reach the goal. Negative means the
    /// user needs to lose more; positive means gain.
    var remainingToGoal: Double? {
        guard let goalWeightKilograms, let current = currentWeightKilograms else { return nil }
        return goalWeightKilograms - current
    }

    /// Fraction of the journey from baseline to goal that is complete, clamped
    /// to `0...1`.
    ///
    /// Returns `nil` when there is no goal, or when the baseline already equals
    /// the goal — in that case there is no journey to measure and showing a
    /// bar at 0% or 100% would both be misleading.
    var goalProgress: Double? {
        guard
            let goal = goalWeightKilograms,
            let start = startingWeightKilograms,
            let current = currentWeightKilograms
        else { return nil }

        let span = goal - start
        guard abs(span) > 0.05 else { return nil }

        let travelled = current - start
        return min(max(travelled / span, 0), 1)
    }

    /// True once the latest reading has reached or passed the goal.
    var hasReachedGoal: Bool {
        guard
            let goal = goalWeightKilograms,
            let start = startingWeightKilograms,
            let current = currentWeightKilograms
        else { return false }

        return goal < start ? current <= goal : current >= goal
    }

    /// Simple moving average of the last `days` days, which smooths out daily
    /// water-weight noise. `nil` when the window contains no entries.
    func movingAverage(days: Int, endingAt referenceDate: Date = .now, calendar: Calendar = .current) -> Double? {
        guard days > 0 else { return nil }
        guard let windowStart = calendar.date(byAdding: .day, value: -days, to: referenceDate) else { return nil }

        let window = entries.filter { $0.measuredAt > windowStart && $0.measuredAt <= referenceDate }
        guard !window.isEmpty else { return nil }

        let total = window.reduce(0.0) { $0 + $1.weightKilograms }
        return total / Double(window.count)
    }

    /// The most recent entry that has a photo attached.
    var latestPhotoEntry: WeightEntrySnapshot? {
        entries.last { $0.hasPhoto }
    }

    /// Entries newest first, capped at `limit`. What Home's recent list shows.
    func mostRecent(_ limit: Int) -> [WeightEntrySnapshot] {
        Array(entries.reversed().prefix(limit))
    }
}
