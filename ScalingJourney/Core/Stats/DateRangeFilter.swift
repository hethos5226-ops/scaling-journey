import Foundation

/// The time windows offered on the Progress screen.
///
/// Defined in Phase 1 because both Home and Progress need a shared vocabulary
/// for "recent"; the chart that consumes the full set arrives in Phase 2.
enum DateRangeFilter: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case threeMonths
    case sixMonths
    case year
    case allTime

    var id: String { rawValue }

    /// Compact label for a segmented control.
    var shortTitle: String {
        switch self {
        case .week: "7D"
        case .month: "30D"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .year: "1Y"
        case .allTime: "All"
        }
    }

    var displayName: String {
        switch self {
        case .week: "Last 7 days"
        case .month: "Last 30 days"
        case .threeMonths: "Last 3 months"
        case .sixMonths: "Last 6 months"
        case .year: "Last year"
        case .allTime: "All time"
        }
    }

    /// Length of the window in days, or `nil` for `.allTime`.
    var dayCount: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .sixMonths: 180
        case .year: 365
        case .allTime: nil
        }
    }

    /// Inclusive lower bound of the window, or `nil` when unbounded.
    func startDate(relativeTo referenceDate: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let dayCount else { return nil }
        return calendar.date(byAdding: .day, value: -dayCount, to: referenceDate)
    }

    /// Filters entries to this window. `.allTime` returns the input unchanged.
    func filter(
        _ entries: [WeightEntrySnapshot],
        relativeTo referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [WeightEntrySnapshot] {
        guard let start = startDate(relativeTo: referenceDate, calendar: calendar) else { return entries }
        return entries.filter { $0.measuredAt >= start }
    }
}
