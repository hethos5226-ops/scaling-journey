import SwiftUI

/// The primary screen: where the journey stands today, and where a new entry
/// is logged.
struct HomeView: View {
    @Binding var selectedTab: AppTab
    @Binding var isPresentingLogSheet: Bool

    @Environment(AppDependencies.self) private var dependencies
    @State private var entryBeingEdited: WeightEntrySnapshot?

    private var journey: JourneyStore { dependencies.journey }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    if journey.hasEntries {
                        loggedContent
                    } else {
                        FirstEntryPrompt(isPresentingLogSheet: $isPresentingLogSheet)
                    }
                }
                .padding(.horizontal, Theme.Space.screenHorizontal)
                .padding(.top, Theme.Space.xs)
                .padding(.bottom, Theme.Space.xxl)
            }
            .background(Color.sjBackground)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if dependencies.isRunningEphemerally {
                    ToolbarItem(placement: .topBarTrailing) {
                        EphemeralStoreWarningButton()
                    }
                }
            }
            .sheet(item: $entryBeingEdited) { entry in
                LogEntryView(mode: .edit(entry))
            }
        }
    }

    @ViewBuilder
    private var loggedContent: some View {
        let statistics = journey.statistics

        HomeHeroCard(statistics: statistics, formatter: journey.formatter, journey: journey)

        Button("Log Weight") {
            isPresentingLogSheet = true
        }
        .buttonStyle(SJPrimaryButtonStyle())

        LatestPhotoCard(
            entry: statistics.latestPhotoEntry,
            formatter: journey.formatter,
            onTap: { entryBeingEdited = $0 },
            onAddPhoto: { isPresentingLogSheet = true }
        )

        RecentEntriesCard(
            entries: statistics.mostRecent(5),
            journey: journey,
            onSelect: { entryBeingEdited = $0 },
            onSeeAll: { selectedTab = .progress }
        )
    }
}

// MARK: - First run

/// What a brand-new user sees. One clear idea and one clear action.
private struct FirstEntryPrompt: View {
    @Binding var isPresentingLogSheet: Bool

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            SJCard(padding: Theme.Space.xl) {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Color.sjAccent)
                        .padding(.bottom, Theme.Space.xxs)

                    Text("Start your journey")
                        .font(.sjSectionTitle)
                        .foregroundStyle(Color.sjPrimaryText)

                    Text("Log your weight with a photo and watch the two tell the story together. Everything stays private on this device.")
                        .font(.sjBody)
                        .foregroundStyle(Color.sjSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button("Log Your First Weight") {
                isPresentingLogSheet = true
            }
            .buttonStyle(SJPrimaryButtonStyle())
        }
    }
}

// MARK: - Ephemeral store warning

/// Shown only when the on-disk database could not be opened. Rare, but a user
/// must never log a month of entries into a store that will not survive a
/// relaunch without being told.
private struct EphemeralStoreWarningButton: View {
    @State private var isPresentingExplanation = false

    var body: some View {
        Button {
            isPresentingExplanation = true
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .accessibilityLabel("Storage warning")
        .alert("Entries will not be saved", isPresented: $isPresentingExplanation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Scaling Journey could not open its database, so anything you log now will be lost when you close the app. Restarting your device usually fixes this.")
        }
    }
}
