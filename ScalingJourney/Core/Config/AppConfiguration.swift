import Foundation

/// Build-time configuration, read from Info.plist keys that are populated by
/// `Config/Base.xcconfig` (and overridden by the gitignored `Secrets.xcconfig`).
///
/// Nothing secret is ever hard-coded in Swift. An absent or empty value means
/// "this integration is not configured", and the app degrades to fully local
/// behaviour rather than crashing or showing a dead button.
struct AppConfiguration: Sendable {
    var apiBaseURL: URL?
    var googleClientID: String?

    static let current = AppConfiguration(bundle: .main)

    init(bundle: Bundle) {
        self.apiBaseURL = Self.string(for: "SJAPIBaseURL", in: bundle).flatMap(URL.init(string:))
        self.googleClientID = Self.string(for: "SJGoogleClientID", in: bundle)
    }

    init(apiBaseURL: URL?, googleClientID: String?) {
        self.apiBaseURL = apiBaseURL
        self.googleClientID = googleClientID
    }

    /// True when a backend is reachable, which gates cloud sign-in and sync.
    var isBackendConfigured: Bool { apiBaseURL != nil }

    var isGoogleSignInConfigured: Bool { googleClientID != nil }

    /// Reads a string, treating whitespace-only values as absent. xcconfig
    /// variables that are declared but empty arrive here as `""`.
    private static func string(for key: String, in bundle: Bundle) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
