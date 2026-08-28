import SwiftUI

@main
@MainActor
struct ScalingJourneyApp: App {
    /// Built once and held for the app's lifetime. `@State` rather than
    /// `@StateObject` because `AppDependencies` uses the Observation framework.
    @State private var dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .modelContainer(dependencies.modelContainer)
                .task {
                    await dependencies.start()
                }
        }
    }
}
