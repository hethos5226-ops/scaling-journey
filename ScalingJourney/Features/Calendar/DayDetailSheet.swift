import SwiftUI

/// What happened on one day — or an invitation to record it.
struct DayDetailSheet: View {
    var date: Date

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var entryBeingEdited: WeightEntrySnapshot?
    @State private var isPresentingNewEntry = false

    private var journey: JourneyStore { dependencies.journey }
    private var entries: [WeightEntrySnapshot] { journey.entries(on: date) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    if entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(entries) { entry in
                            DayEntryCard(entry: entry, formatter: journey.formatter) {
                                entryBeingEdited = entry
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.screenHorizontal)
                .padding(.vertical, Theme.Space.lg)
            }
            .background(Color.sjBackground)
            .navigationTitle(date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $entryBeingEdited) { entry in
                LogEntryView(mode: .edit(entry))
            }
            .sheet(isPresented: $isPresentingNewEntry) {
                // Opens pre-dated to the tapped day, at the current time of day.
                LogEntryView(mode: .create(date: startingDateForNewEntry))
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents(entries.isEmpty ? [.medium] : [.large])
    }

    private var emptyState: some View {
        SJCard(padding: Theme.Space.xl) {
            SJEmptyState(
                systemImage: "square.and.pencil",
                title: "Nothing logged",
                message: "Add an entry for this day if you weighed yourself and forgot to record it."
            ) {
                Button("Add Entry") { isPresentingNewEntry = true }
                    .buttonStyle(SJPrimaryButtonStyle())
            }
        }
    }

    /// The tapped day, keeping the current wall-clock time — but never in the
    /// future, since today's cell would otherwise produce a future timestamp
    /// when tapped early in the day.
    private var startingDateForNewEntry: Date {
        let calendar = Calendar.current
        let now = Date.now
        let time = calendar.dateComponents([.hour, .minute], from: now)
        let combined = calendar.date(
            bySettingHour: time.hour ?? 9,
            minute: time.minute ?? 0,
            second: 0,
            of: date
        ) ?? date
        return min(combined, now)
    }
}

// MARK: - Entry card

private struct DayEntryCard: View {
    var entry: WeightEntrySnapshot
    var formatter: WeightFormatter
    var onEdit: () -> Void

    var body: some View {
        SJCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(formatter.string(fromKilograms: entry.weightKilograms))
                        .font(.system(size: 30, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.sjPrimaryText)

                    Spacer()

                    Text(entry.measuredAt, style: .time)
                        .font(.sjCaption)
                        .foregroundStyle(Color.sjSecondaryText)
                }

                if let photo = entry.photo {
                    SJAspectFill(cornerRadius: Theme.Radius.medium) {
                        SJPhotoImage(assetIdentifier: photo.assetIdentifier, variant: .full) {
                            SJPhotoPlaceholder(systemImage: "photo")
                        }
                    }
                }

                if let note = entry.note, entry.hasNote {
                    Text(note)
                        .font(.sjBody)
                        .foregroundStyle(Color.sjSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Edit", action: onEdit)
                    .buttonStyle(SJSecondaryButtonStyle())
            }
        }
    }
}
