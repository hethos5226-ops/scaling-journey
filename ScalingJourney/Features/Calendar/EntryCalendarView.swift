import SwiftUI

/// A month at a glance: which days have entries, and what kind.
struct EntryCalendarView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: CalendarDay?

    private var journey: JourneyStore { dependencies.journey }
    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    SJCard(padding: Theme.Space.md) {
                        VStack(spacing: Theme.Space.md) {
                            monthHeader
                            CalendarMonthGrid(
                                month: displayedMonth,
                                entriesByDay: entriesByDay,
                                onSelectDay: { selectedDay = CalendarDay(date: $0) }
                            )
                        }
                    }

                    CalendarLegend()
                }
                .padding(.horizontal, Theme.Space.screenHorizontal)
                .padding(.top, Theme.Space.xs)
                .floatingButtonClearance()
            }
            .background(Color.sjBackground)
            .navigationTitle("Calendar")
            .sheet(item: $selectedDay) { day in
                DayDetailSheet(date: day.date)
            }
        }
    }

    // MARK: Month navigation

    private var monthHeader: some View {
        HStack {
            monthButton(systemImage: "chevron.left", offset: -1, label: "Previous month")

            Spacer()

            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.sjSectionTitle)
                .foregroundStyle(Color.sjPrimaryText)
                .contentTransition(.opacity)

            Spacer()

            monthButton(systemImage: "chevron.right", offset: 1, label: "Next month")
                // Nothing has been logged in the future, so browsing past the
                // current month is a dead end.
                .disabled(isDisplayingCurrentMonth)
                .opacity(isDisplayingCurrentMonth ? 0.3 : 1)
        }
    }

    private func monthButton(systemImage: String, offset: Int, label: String) -> some View {
        Button {
            guard let next = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
            withAnimation(Theme.Motion.standard) {
                displayedMonth = calendar.startOfMonth(for: next)
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    // MARK: Data

    /// Entries for the displayed month, bucketed by start-of-day.
    ///
    /// Built once per render rather than filtering inside each of the 42 cells,
    /// which would be quadratic in the number of entries.
    private var entriesByDay: [Date: [WeightEntrySnapshot]] {
        guard let range = calendar.monthInterval(for: displayedMonth) else { return [:] }

        let inMonth = journey.entries.filter { range.contains($0.measuredAt) }
        return Dictionary(grouping: inMonth) { calendar.startOfDay(for: $0.measuredAt) }
    }
}

/// Wrapper that makes a selected date usable with `sheet(item:)`.
struct CalendarDay: Identifiable, Hashable {
    var date: Date
    var id: Date { date }
}

// MARK: - Legend

/// Explains the three indicator states. Small, but without it the difference
/// between a tinted dot and a photo tile is a guessing game.
private struct CalendarLegend: View {
    var body: some View {
        SJCard(padding: Theme.Space.md) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("What the days mean")
                    .sjLabelStyle()

                legendRow(swatch: { Circle().fill(Color.sjSurfaceElevated) }, text: "Weight logged")
                legendRow(
                    swatch: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.sjAccent.opacity(0.85))
                    },
                    text: "Weight and photo"
                )
                legendRow(
                    swatch: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.sjAccent.opacity(0.85))
                            .overlay(alignment: .topTrailing) {
                                Circle()
                                    .fill(Color.sjPrimaryText)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                    },
                    text: "Weight, photo and note"
                )
            }
        }
    }

    private func legendRow<S: View>(@ViewBuilder swatch: () -> S, text: String) -> some View {
        HStack(spacing: Theme.Space.sm) {
            swatch()
                .frame(width: 22, height: 22)
            Text(text)
                .font(.sjCaption)
                .foregroundStyle(Color.sjSecondaryText)
        }
    }
}

// MARK: - Calendar helpers

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }

    /// The half-open interval covering the whole month containing `date`.
    func monthInterval(for date: Date) -> Range<Date>? {
        let start = startOfMonth(for: date)
        guard let end = self.date(byAdding: DateComponents(month: 1), to: start) else { return nil }
        return start..<end
    }
}
