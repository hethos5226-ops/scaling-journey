import Foundation
import SwiftData

/// Version 1 of the persisted schema.
///
/// Declaring a `VersionedSchema` now — before there is anything to migrate —
/// is what makes later additions (body measurements, custom fields, multiple
/// photos per pose) a routine migration rather than a data-loss event.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [WeightEntry.self, ProgressPhoto.self, UserProfile.self]
    }
}

/// Ordered list of schema versions and the migration stages between them.
///
/// Add the next `VersionedSchema` to `schemas` and a `MigrationStage` to
/// `stages` when the model layer changes.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// The schema the app currently runs against.
enum AppSchema {
    static var current: Schema { Schema(versionedSchema: AppSchemaV1.self) }
}
