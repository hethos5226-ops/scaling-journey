import Foundation

/// Credentials handed to `AuthenticationService.signIn`.
///
/// Modelled as an enum so adding a provider is a compile error everywhere that
/// needs updating, rather than a silently unhandled string.
enum AuthCredentials: Sendable {
    /// Continue without an account. Data stays on this device.
    case device
    /// Identity token returned by `ASAuthorizationAppleIDCredential`.
    case apple(identityToken: Data, fullName: PersonNameComponents?, email: String?)
    /// ID token returned by the Google Sign-In SDK.
    case google(idToken: String, accessToken: String)
    case email(address: String, password: String)

    var provider: AuthProvider {
        switch self {
        case .device: .device
        case .apple: .apple
        case .google: .google
        case .email: .email
        }
    }
}

/// Authentication and account lifecycle.
///
/// Phase 1 ships `LocalAccountAuthenticationService`, which only supports
/// `.device`. The protocol already describes everything the real backend needs
/// — including the two operations the App Store review guidelines require of an
/// app that offers accounts: `deleteAccount` and a data export path.
protocol AuthenticationService: Sendable {
    /// The account restored from a previous launch, if any.
    func restoreSession() async -> Account?

    func signIn(with credentials: AuthCredentials) async throws -> Account

    /// Ends the session on this device. Local data is left untouched: signing
    /// out must never be a data-loss event.
    func signOut() async throws

    /// Permanently deletes the account and all server-side data.
    ///
    /// Required by App Store Review Guideline 5.1.1(v) for any app offering
    /// account creation. Deleting local data is the caller's responsibility.
    func deleteAccount() async throws

    /// Which providers this build can actually offer, so the sign-in UI never
    /// shows a button that cannot work.
    var availableProviders: [AuthProvider] { get }
}

/// The authentication service used when no backend is configured.
///
/// Creates a single stable device-local account so the whole app — profiles,
/// entries, photos — can be written against "the signed-in account" from day
/// one. When a real backend arrives, this identifier is what gets migrated to
/// the server account, so nothing is orphaned.
final class LocalAccountAuthenticationService: AuthenticationService {
    private let store: AccountIdentifierStore

    init(store: AccountIdentifierStore = KeychainAccountIdentifierStore()) {
        self.store = store
    }

    var availableProviders: [AuthProvider] { [.device] }

    func restoreSession() async -> Account? {
        guard let identifier = store.currentIdentifier() else { return nil }
        return Account(identifier: identifier, provider: .device)
    }

    func signIn(with credentials: AuthCredentials) async throws -> Account {
        guard case .device = credentials else { throw AuthError.notConfigured }
        let identifier = store.currentIdentifier() ?? store.createIdentifier()
        return Account(identifier: identifier, provider: .device)
    }

    func signOut() async throws {
        // A device-local account has no session to end. The identifier is
        // deliberately kept so the user's existing entries stay reachable.
    }

    func deleteAccount() async throws {
        store.clear()
    }
}
