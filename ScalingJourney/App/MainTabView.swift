import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home
    case progress
    case calendar
    case settings

    var title: String {
        switch self {
        case .home: "Home"
        case .progress: "Progress"
        case .calendar: "Calendar"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .progress: "chart.xyaxis.line"
        case .calendar: "calendar"
        case .settings: "gearshape"
        }
    }
}

/// The four main areas, plus the floating log button.
struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @Binding var isPresentingLogSheet: Bool

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home carries its own large "Log Weight" button, so it does not
            // also get the floating one — two ways to do the same thing in the
            // same viewport is clutter, not emphasis.
            HomeView(selectedTab: $selectedTab, isPresentingLogSheet: $isPresentingLogSheet)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            ProgressDashboardView()
                .logButtonOverlay(isPresenting: $isPresentingLogSheet)
                .tabItem { Label(AppTab.progress.title, systemImage: AppTab.progress.systemImage) }
                .tag(AppTab.progress)

            EntryCalendarView()
                .logButtonOverlay(isPresenting: $isPresentingLogSheet)
                .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage) }
                .tag(AppTab.calendar)

            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
                .tag(AppTab.settings)
        }
    }
}

// MARK: - Floating log button

/// A persistent, thumb-reachable way to log from any of the three data tabs.
///
/// A floating circular button rather than a fifth "Log" tab: a tab that never
/// stays selected — it opens a sheet and springs back — is a small lie about
/// what tabs do, and it flashes an empty screen on the way. This follows the
/// same pattern as Notes' compose button.
private struct LogButtonOverlay: ViewModifier {
    @Binding var isPresenting: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                Button {
                    isPresenting = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 58, height: 58)
                        .background(Color.sjAccent, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
                }
                .buttonStyle(FloatingButtonStyle())
                .padding(.trailing, Theme.Space.lg)
                .padding(.bottom, Theme.Space.lg)
                .accessibilityLabel("Log weight")
                .accessibilityHint("Opens the form for recording a new weight and photo")
            }
    }
}

private struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

extension View {
    func logButtonOverlay(isPresenting: Binding<Bool>) -> some View {
        modifier(LogButtonOverlay(isPresenting: isPresenting))
    }
}

/// Bottom padding that keeps scrollable content clear of the floating button.
extension View {
    func floatingButtonClearance() -> some View {
        padding(.bottom, 92)
    }
}
