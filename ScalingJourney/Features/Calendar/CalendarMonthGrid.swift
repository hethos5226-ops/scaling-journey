import SwiftUI

/// A month laid out as a seven-column grid.
struct CalendarMonthGrid: View {
    var month: Date
    var entriesByDay: [Date: [WeightEntrySnapshot]]
    var onSelectDay: (Date) -> Void

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            weekdayHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                // Identified by position, not value: the leading blanks are all
                // `nil`, so `id: \.self` would give several cells the same id.
                ForEach(Array(gridDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        CalendarDayCell(
                            date: date,
                            entries: entriesByDay[calendar.startOfDay(for: date)] ?? [],
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date.now
                        )
                        .onTapGesture { onSelectDay(date) }
                    } else {
                        // Leading padding days from the previous month.
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    /// Localised one-letter weekday initials, rotated to the locale's first
    /// weekday so the columns line up with the grid below.
    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        let ordered = Array(symbols[firstIndex...] + symbols[..<firstIndex])

        return HStack(spacing: 4) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.sjTertiaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// Dates for the grid, with `nil` placeholders for the blank cells before
    /// the first of the month.
    private var gridDates: [Date?] {
        let start = calendar.startOfMonth(for: month)
        guard let dayRange = calendar.range(of: .day, in: .month, for: start) else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: start)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var dates: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayRange.count {
            dates.append(calendar.date(byAdding: .day, value: offset, to: start))
        }
        return dates
    }
}

// MARK: - Day cell

/// One day.
///
/// Days with a photo show the photo itself rather than an abstract marker —
/// this is a visual progress journal, and a month view made of the user's own
/// images is far more motivating than a grid of dots.
struct CalendarDayCell: View {
    var date: Date
    var entries: [WeightEntrySnapshot]
    var isToday: Bool
    var isFuture: Bool

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    /// The entry that represents the day: the first one with a photo, else the
    /// first logged.
    private var representativeEntry: WeightEntrySnapshot? {
        entries.first(where: { $0.hasPhoto }) ?? entries.first
    }

    private var hasPhoto: Bool { representativeEntry?.hasPhoto ?? false }
    private var hasEntry: Bool { !entries.isEmpty }
    private var hasNote: Bool { entries.contains(where: \.hasNote) }

    var body: some View {
        ZStack {
            background

            Text(dayNumber)
                .font(.system(size: 15, weight: hasEntry ? .semibold : .regular))
                .foregroundStyle(numberColor)
                .shadow(color: hasPhoto ? .black.opacity(0.6) : .clear, radius: 2, y: 1)
        }
        .frame(height: 44)
        .overlay(alignment: .topTrailing) {
            if hasNote {
                Circle()
                    .fill(hasPhoto ? Color.white : Color.sjAccent)
                    .frame(width: 6, height: 6)
                    .padding(4)
            }
        }
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.sjAccent, lineWidth: 1.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(isFuture ? 0.35 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var background: some View {
        if let photo = representativeEntry?.photo {
            // The cell's width comes from the grid, so the photo is placed as
            // an overlay on a clear base: that pins it to the cell's bounds
            // instead of letting the image's own size drive the layout.
            Color.clear
                .overlay {
                    SJPhotoImage(assetIdentifier: photo.assetIdentifier, variant: .thumbnail) {
                        Color.sjAccent.opacity(0.35)
                    }
                }
                // A scrim so the day number stays readable over any photo.
                .overlay { Color.black.opacity(0.25) }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if hasEntry {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.sjSurfaceElevated)
        } else {
            Color.clear
        }
    }

    private var numberColor: Color {
        if hasPhoto { return .white }
        if hasEntry { return .sjPrimaryText }
        return .sjSecondaryText
    }

    private var accessibilityLabel: String {
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard hasEntry else { return "\(day), no entry" }

        var parts = ["\(day), weight logged"]
        if hasPhoto { parts.append("with photo") }
        if hasNote { parts.append("with note") }
        return parts.joined(separator: ", ")
    }
}
