import SwiftUI

/// Statistics and history for a chosen time window.
///
/// Phase 1 deliberately stops at the numbers and the list. The weight chart,
/// point selection and before/after comparison build on exactly this data and
/// this range selector, so they slot in without rework.
///
/// Named `ProgressDashboardView` rather than `ProgressView` because SwiftUI
/// already owns that name.
struct ProgressDashboardView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var range: DateRangeFilter = .month
    @State private var entryBeingEdited: WeightEntrySnapshot?

    private var journey: JourneyStore { dependencies.journey }

    var body: some View {
        NavigationStack {
            ScrollView {
                if journey.hasEntries {
                    content
                } else {
                    SJEmptyState(
                        systemImage: "chart.xyaxis.line",
                        title: "Nothing to chart yet",
                        message: "Log a few weights and your trends will appear here."
                    )
                    .padding(.top, Theme.Space.xxxl)
                }
            }
            .background(Color.sjBackground)
            .navigationTitle("Progress")
            .sheet(item: $entryBeingEdited) { entry in
                LogEntryView(mode: .edit(entry))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        // Statistics are recomputed for the selected window, so "highest" and
        // "lowest" mean highest and lowest *in this range* — which is what a
        // range selector implies.
        let windowed = ProgressStatistics(
            entries: range.filter(journey.entries),
            goalWeightKilograms: journey.profile?.goalWeightKilograms,
            startingWeightOverride: journey.profile?.startingWeightKilogramsOverride
        )
        let formatter = journey.formatter

        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            rangePicker

            if windowed.isEmpty {
                SJCard {
                    SJEmptyState(
                        systemImage: "calendar.badge.exclamationmark",
                        title: "No entries in this range",
                        message: "Try a longer time span to see your history."
                    )
                }
            } else {
                statsGrid(windowed, formatter: formatter)
                historySection(windowed, formatter: formatter)
            }
        }
        .padding(.horizontal, Theme.Space.screenHorizontal)
        .padding(.top, Theme.Space.xs)
        .floatingButtonClearance()
    }

    private var rangePicker: some View {
        Picker("Time range", selection: $range) {
            ForEach(DateRangeFilter.allCases) { filter in
                Text(filter.shortTitle).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Time range")
    }

    private func statsGrid(_ statistics: ProgressStatistics, formatter: WeightFormatter) -> some View {
        SJCard {
            VStack(spacing: Theme.Space.lg) {
                HStack(alignment: .top, spacing: Theme.Space.md) {
                    SJStatTile(
                        label: "Current",
                        value: statistics.currentWeightKilograms.map(formatter.string(fromKilograms:)) ?? "—"
                    )
                    SJStatTile(
                        label: "Starting",
                        value: statistics.startingWeightKilograms.map(formatter.string(fromKilograms:)) ?? "—",
                        caption: statistics.starting.map { $0.measuredAt.formatted(.dateTime.day().month(.abbreviated)) }
                    )
                }

                Divider().overlay(Color.sjSeparator)

                HStack(alignment: .top, spacing: Theme.Space.md) {
                    SJStatTile(
                        label: "Lowest",
                        value: statistics.lowest.map { formatter.string(fromKilograms: $0.weightKilograms) } ?? "—",
                        caption: statistics.lowest.map { $0.measuredAt.formatted(.dateTime.day().month(.abbreviated)) }
                    )
                    SJStatTile(
                        label: "Highest",
                        value: statistics.highest.map { formatter.string(fromKilograms: $0.weightKilograms) } ?? "—",
                        caption: statistics.highest.map { $0.measuredAt.formatted(.dateTime.day().month(.abbreviated)) }
                    )
                }

                Divider().overlay(Color.sjSeparator)

                HStack(alignment: .top, spacing: Theme.Space.md) {
                    SJStatTile(
                        label: "Total change",
                        value: statistics.changeSinceStart.map { formatter.signedChange(kilograms: $0) } ?? "—",
                        tint: journey.tint(for: statistics.changeSinceStart).color
                    )
                    SJStatTile(
                        label: "7-day average",
                        value: statistics.movingAverage(days: 7).map(formatter.string(fromKilograms:)) ?? "—",
                        caption: "Smooths daily swings"
                    )
                }

                if statistics.goalWeightKilograms != nil {
                    Divider().overlay(Color.sjSeparator)
                    GoalProgressSection(statistics: statistics, formatter: formatter)
                }
            }
        }
    }

    private func historySection(_ statistics: ProgressStatistics, formatter: WeightFormatter) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SJSectionHeader("History") {
                Text("\(statistics.entries.count) \(statistics.entries.count == 1 ? "entry" : "entries")")
                    .font(.sjCaption)
                    .foregroundStyle(Color.sjSecondaryText)
            }

            SJCard(padding: Theme.Space.md) {
                VStack(spacing: 0) {
                    let ordered = Array(statistics.entries.reversed())
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, entry in
                        let change = journey.changeSincePreviousEntry(for: entry)

                        Button {
                            entryBeingEdited = entry
                        } label: {
                            SJEntryRow(
                                entry: entry,
                                formatter: formatter,
                                change: change,
                                changeTint: journey.tint(for: change)
                            )
                        }
                        .buttonStyle(.plain)

                        if index < ordered.count - 1 {
                            Divider()
                                .overlay(Color.sjSeparator)
                                .padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }
}
