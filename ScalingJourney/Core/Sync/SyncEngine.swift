import Foundation

/// What the UI needs to know about background synchronisation.
enum SyncStatus: Equatable, Sendable {
    /// No backend configured: everything lives on this device.
    case disabled
    case idle(lastSyncedAt: Date?)
    case syncing
    case failed(message: String)

    var isEnabled: Bool { self != .disabled }
}

/// Pushes local changes to a backend and pulls remote ones down.
///
/// No implementation ships in Phase 1 — `DisabledSyncEngine` is a no-op. The
/// protocol exists now so that the app's data flow is already shaped correctly:
/// every mutation goes through a repository, every record carries
/// `updatedAt`/`remoteID`/`syncState`, and deletes are tombstones. Adding a
/// real engine later is additive rather than a rewrite.
protocol SyncEngine: Sendable {
    var status: SyncStatus { get async }

    /// Runs a full reconciliation pass.
    func synchronise() async throws

    /// Hints that local data changed and a push is worth scheduling.
    func scheduleUpload() async
}

/// The engine used while no backend is configured.
struct DisabledSyncEngine: SyncEngine {
    var status: SyncStatus { get async { .disabled } }

    func synchronise() async throws {}
    func scheduleUpload() async {}
}
