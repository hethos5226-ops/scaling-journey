import Foundation
import OSLog

/// Centralised loggers.
///
/// Every message must stay free of personal data: no weights, notes, photo
/// contents or account identifiers. This app holds unusually sensitive
/// material, and device logs are readable by anyone with the device.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.scalingjourney.ScalingJourney"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let photos = Logger(subsystem: subsystem, category: "photos")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
