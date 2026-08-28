import Foundation

/// Where a weight reading came from.
///
/// Recording provenance now means a later HealthKit or CSV import can be
/// re-run, reconciled or undone without guessing which rows the user typed by
/// hand. `externalIdentifier` on `WeightEntry` holds the source system's own
/// id (a `HKSample.uuid`, a CSV row fingerprint) so imports stay idempotent.
enum EntrySource: String, Codable, CaseIterable, Sendable {
    case manual
    case csvImport
    case healthKit

    var displayName: String {
        switch self {
        case .manual: "Logged in app"
        case .csvImport: "Imported from CSV"
        case .healthKit: "Apple Health"
        }
    }
}

/// Tracks whether a record still needs to be pushed to a backend.
///
/// Phase 1 has no backend, so everything sits at `.localOnly`. The field exists
/// from day one so switching on cloud sync later is a behaviour change rather
/// than a schema migration.
enum SyncState: String, Codable, Sendable {
    /// Never sent anywhere. The only state a Phase 1 record can be in.
    case localOnly
    /// Has local changes that a backend has not acknowledged yet.
    case pendingUpload
    /// Matches what the backend last confirmed.
    case synced
}
