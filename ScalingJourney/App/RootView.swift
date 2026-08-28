import SwiftUI

/// Top-level container.
///
/// Holds the tab bar, the globally presented "log an entry" sheet, and the
/// launch state while the account is being restored.
struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var selectedTab: AppTab = .home
    @State private var isPresentingLogSheet = false

    var body: some View {
        @Bindable var journey = dependencies.journey

        Group {
            if dependencies.journey.isLoading {
                LaunchPlaceholderView()
                    .transition(.opacity)
            } else {
                MainTabView(
                    selectedTab: $selectedTab,
                    isPresentingLogSheet: $isPresentingLogSheet
                )
                .transition(.opacity)
            }
        }
        .animation(Theme.Motion.standard, value: dependencies.journey.isLoading)
        .sheet(isPresented: $isPresentingLogSheet) {
            LogEntryView(mode: .create(date: .now))
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { journey.errorMessage != nil },
                set: { if !$0 { journey.errorMessage = nil } }
            ),
            presenting: journey.errorMessage
        ) { _ in
            Button("OK", role: .cancel) { journey.errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }
}

/// Shown for the brief moment between launch and the account being restored.
/// Deliberately near-empty: a spinner on a blank canvas reads as calm, whereas
/// a half-populated Home screen that then rearranges reads as broken.
private struct LaunchPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.sjBackground.ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .tint(Color.sjSecondaryText)
        }
    }
}
