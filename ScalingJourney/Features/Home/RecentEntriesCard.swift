import SwiftUI

/// The last few entries, newest first.
struct RecentEntriesCard: View {
    var entries: [WeightEntrySnapshot]
    var journey: JourneyStore
    var onSelect: (WeightEntrySnapshot) -> Void
    var onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SJSectionHeader("Recent") {
                Button("See all", action: onSeeAll)
                    .font(.sjCaptionEmphasis)
            }

            SJCard(padding: Theme.Space.md) {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let change = journey.changeSincePreviousEntry(for: entry)

                        Button {
                            onSelect(entry)
                        } label: {
                            SJEntryRow(
                                entry: entry,
                                formatter: journey.formatter,
                                change: change,
                                changeTint: journey.tint(for: change)
                            )
                        }
                        .buttonStyle(.plain)

                        if index < entries.count - 1 {
                            Divider()
                                .overlay(Color.sjSeparator)
                                // Inset to align with the text, not the thumbnail.
                                .padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }
}
