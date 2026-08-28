import Foundation
import Observation
import SwiftData

/// Composition root.
///
/// Everything the app depends on is constructed here and nowhere else. Screens
/// receive it through the SwiftUI environment, so replacing the local photo
/// store with cloud storage, or the device-local auth service with a real
/// backend, is a change to this one file.
@MainActor
@Observable
final class AppDependencies {
    let configuration: AppConfiguration
    let modelContainer: ModelContainer
    let photoStore: any PhotoStore
    let syncEngine: any SyncEngine
    let auth: AuthController
    let journey: JourneyStore

    /// True when the on-disk store could not be opened and the app is running
    /// against a temporary in-memory database. Surfaced in the UI so a user is
    /// never quietly logging into a store that will not survive relaunch.
    let isRunningEphemerally: Bool

    init(
        configuration: AppConfiguration = .current,
        modelContainer: ModelContainer,
        isRunningEphemerally: Bool = false,
        photoStore: any PhotoStore,
        syncEngine: any SyncEngine,
        authenticationService: any AuthenticationService
    ) {
        self.configuration = configuration
        self.modelContainer = modelContainer
        self.isRunningEphemerally = isRunningEphemerally
        self.photoStore = photoStore
        self.syncEngine = syncEngine
        self.auth = AuthController(service: authenticationService)

        let context = modelContainer.mainContext
        self.journey = JourneyStore(
            entryRepository: SwiftDataWeightEntryRepository(context: context),
            profileRepository: SwiftDataProfileRepository(context: context),
            photoStore: photoStore,
            syncEngine: syncEngine
        )
    }

    /// The configuration the shipping app runs with.
    ///
    /// Auth and sync are selected from build configuration: with no backend
    /// URL set, the app is a fully functional local journal. That is the
    /// intended Phase 1 behaviour, not a degraded mode.
    static func live() -> AppDependencies {
        let (container, isEphemeral) = ModelContainerFactory.makeResilient()

        return AppDependencies(
            modelContainer: container,
            isRunningEphemerally: isEphemeral,
            photoStore: FilePhotoStore(),
            syncEngine: DisabledSyncEngine(),
            authenticationService: LocalAccountAuthenticationService()
        )
    }

    /// Signs in (or restores), then loads that account's data.
    func start() async {
        await auth.bootstrap()
        guard let account = auth.state.account else { return }

        await journey.load(accountIdentifier: account.identifier)
        // Housekeeping, after the UI already has its data.
        await journey.removeOrphanedPhotos()
    }
}
