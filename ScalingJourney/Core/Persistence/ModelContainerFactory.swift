import Foundation
import SwiftData

/// Builds the app's SwiftData container.
///
/// Kept separate from the app entry point so tests and previews can ask for an
/// in-memory store with the exact same schema the app runs.
enum ModelContainerFactory {
    /// The on-disk store used by the running app.
    ///
    /// - Parameter storeName: file name for the SQLite store, overridable so a
    ///   future multi-account mode can keep accounts in separate stores.
    static func makePersistent(storeName: String = "ScalingJourney.store") throws -> ModelContainer {
        let url = URL.applicationSupportDirectory.appending(path: storeName)
        try FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory,
            withIntermediateDirectories: true
        )

        let configuration = ModelConfiguration(url: url)
        return try ModelContainer(
            for: AppSchema.current,
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
    }

    /// A throwaway container for tests and SwiftUI previews.
    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: AppSchema.current,
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
    }

    /// Persistent store, falling back to an in-memory one if the disk store
    /// cannot be opened.
    ///
    /// A corrupt or unreadable store must never be a launch crash: the user
    /// gets a working (if empty) app and a clear message, which is far better
    /// App Store behaviour than a boot loop. The caller learns which path was
    /// taken via the returned flag so it can surface a warning.
    static func makeResilient(storeName: String = "ScalingJourney.store") -> (container: ModelContainer, isEphemeral: Bool) {
        do {
            return (try makePersistent(storeName: storeName), false)
        } catch {
            AppLog.persistence.error("Falling back to in-memory store: \(String(describing: error))")
            do {
                return (try makeInMemory(), true)
            } catch {
                // An in-memory container failing means the schema itself is
                // invalid, which is a programmer error we cannot recover from.
                preconditionFailure("Unable to create in-memory ModelContainer: \(error)")
            }
        }
    }
}
