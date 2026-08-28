import SwiftUI

/// The headline card: current weight, how it has moved, and goal progress.
struct HomeHeroCard: View {
    var statistics: ProgressStatistics
    var formatter: WeightFormatter
    /// Taken as the store rather than a closure: `tint(for:)` is main-actor
    /// isolated, and passing it as a bare function value would silently drop
    /// that isolation.
    var journey: JourneyStore

    var body: some View {
        SJCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                currentWeight

                if statistics.changeSincePrevious != nil || statistics.changeSinceStart != nil {
                    Divider().overlay(Color.sjSeparator)
                    changeStats
                }

                if statistics.goalWeightKilograms != nil {
                    Divider().overlay(Color.sjSeparator)
                    GoalProgressSection(statistics: statistics, formatter: formatter)
                }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var currentWeight: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text("Current weight")
                .sjLabelStyle()

            if let current = statistics.currentWeightKilograms {
                // The number and its unit are laid out on a shared baseline so
                // the unit sits under the cap height rather than centred.
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                    Text(formatter.number(fromKilograms: current))
                        .font(.sjHeroNumber)
                        .foregroundStyle(Color.sjPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if formatter.unit != .stones {
                        Text(formatter.unit.symbol)
                            .font(.sjHeroUnit)
                            .foregroundStyle(Color.sjSecondaryText)
                    }
                }
                .contentTransition(.numericText())
                .animation(Theme.Motion.standard, value: current)
            }

            if let latest = statistics.latest {
                Text("Logged \(latest.measuredAt, format: .relative(presentation: .named))")
                    .font(.sjCaption)
                    .foregroundStyle(Color.sjTertiaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current weight")
        .accessibilityValue(
            statistics.currentWeightKilograms.map { formatter.string(fromKilograms: $0) } ?? "None"
        )
    }

    @ViewBuilder
    private var changeStats: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            if let sincePrevious = statistics.changeSincePrevious {
                SJStatTile(
                    label: "Since last",
                    value: formatter.signedChange(kilograms: sincePrevious),
                    tint: journey.tint(for: sincePrevious).color,
                    caption: statistics.previous.map { relativeDay($0.measuredAt) }
                )
            }

            if let sinceStart = statistics.changeSinceStart {
                SJStatTile(
                    label: "Since start",
                    value: formatter.signedChange(kilograms: sinceStart),
                    tint: journey.tint(for: sinceStart).color,
                    caption: statistics.starting.map { shortDate($0.measuredAt) }
                )
            }
        }
    }

    // MARK: Helpers

    private func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Earlier today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return shortDate(date)
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Goal progress

/// Progress from the starting weight toward the goal.
///
/// Only shown when a goal exists. The bar measures the *journey*, not the
/// absolute weight, so it reads the same whether the user is losing or gaining.
struct GoalProgressSection: View {
    var statistics: ProgressStatistics
    var formatter: WeightFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Goal")
                    .sjLabelStyle()
                Spacer()
                if let goal = statistics.goalWeightKilograms {
                    Text(formatter.string(fromKilograms: goal))
                        .font(.sjCaptionEmphasis)
                        .monospacedDigit()
                        .foregroundStyle(Color.sjSecondaryText)
                }
            }

            if let progress = statistics.goalProgress {
                GoalProgressBar(progress: progress)
            }

            Text(statusText)
                .font(.sjCaption)
                .foregroundStyle(statistics.hasReachedGoal ? Color.sjAccent : Color.sjSecondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal progress")
        .accessibilityValue(statusText)
    }

    private var statusText: String {
        if statistics.hasReachedGoal {
            return "Goal reached."
        }
        guard let remaining = statistics.remainingToGoal else {
            return "Set a starting point to track progress."
        }
        let amount = formatter.signedChange(kilograms: remaining, includeUnit: true)
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "\u{2212}", with: "")
        return remaining < 0 ? "\(amount) to lose" : "\(amount) to gain"
    }
}

private struct GoalProgressBar: View {
    /// Fraction complete, already clamped to `0...1` by `ProgressStatistics`.
    var progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.sjSurfaceElevated)
                Capsule()
                    .fill(Color.sjAccent)
                    .frame(width: max(proxy.size.width * progress, progress > 0 ? 6 : 0))
            }
        }
        .frame(height: 8)
        .animation(Theme.Motion.standard, value: progress)
        .accessibilityHidden(true)
    }
}
