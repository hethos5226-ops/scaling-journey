import Foundation

/// How a user proved who they are.
enum AuthProvider: String, Codable, CaseIterable, Sendable {
    /// No sign-in yet: data is held on this device only.
    case device
    case apple
    case google
    case email

    var displayName: String {
        switch self {
        case .device: "This device"
        case .apple: "Apple"
        case .google: "Google"
        case .email: "Email"
        }
    }

    /// Whether choosing this provider makes data recoverable on another device.
    var supportsCrossDeviceRecovery: Bool { self != .device }
}

/// The signed-in user.
///
/// `identifier` is what every other record keys off (`UserProfile.accountIdentifier`).
/// It must stay stable for the life of the account: when a device-local account
/// is later upgraded to a real one, the identifier is carried over so existing
/// entries and photos remain attached rather than being orphaned.
struct Account: Identifiable, Hashable, Sendable {
    var identifier: String
    var provider: AuthProvider
    var email: String?
    var displayName: String?
    var createdAt: Date

    var id: String { identifier }

    init(
        identifier: String,
        provider: AuthProvider,
        email: String? = nil,
        displayName: String? = nil,
        createdAt: Date = .now
    ) {
        self.identifier = identifier
        self.provider = provider
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }

    /// True while the user's data exists only on this device.
    var isDeviceLocal: Bool { provider == .device }
}

enum AuthError: LocalizedError, Equatable {
    case notConfigured
    case cancelled
    case invalidCredentials
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Cloud accounts are not available in this build yet."
        case .cancelled:
            "Sign in was cancelled."
        case .invalidCredentials:
            "That email and password combination was not recognised."
        case .network:
            "We could not reach the server. Check your connection and try again."
        }
    }
}
