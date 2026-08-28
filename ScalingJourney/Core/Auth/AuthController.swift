import Foundation
import Observation

/// Observable wrapper around `AuthenticationService` that the UI binds to.
///
/// Views never touch the service directly; they read `state` and call the
/// methods here. That keeps every screen unchanged when the local service is
/// replaced by a real backend.
@MainActor
@Observable
final class AuthController {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(Account)

        var account: Account? {
            if case .signedIn(let account) = self { return account }
            return nil
        }
    }

    private(set) var state: State = .loading
    private(set) var lastError: AuthError?

    private let service: AuthenticationService

    init(service: AuthenticationService) {
        self.service = service
    }

    var availableProviders: [AuthProvider] { service.availableProviders }

    /// True when the current account only exists on this device, which Settings
    /// surfaces as a prompt to create a real account.
    var needsCloudAccount: Bool { state.account?.isDeviceLocal ?? false }

    /// Restores a previous session, or silently establishes a device-local
    /// account so a first-run user reaches Home without a sign-in wall.
    ///
    /// Making sign-in optional is a product decision: forcing account creation
    /// before a user has logged a single weight is the fastest way to lose them,
    /// and their data is portable to a real account later.
    func bootstrap() async {
        if let restored = await service.restoreSession() {
            state = .signedIn(restored)
            return
        }

        do {
            state = .signedIn(try await service.signIn(with: .device))
        } catch {
            AppLog.auth.error("Bootstrap sign-in failed: \(String(describing: error))")
            state = .signedOut
        }
    }

    func signIn(with credentials: AuthCredentials) async {
        lastError = nil
        do {
            state = .signedIn(try await service.signIn(with: credentials))
        } catch let error as AuthError {
            lastError = error
        } catch {
            lastError = .network(String(describing: error))
        }
    }

    func signOut() async {
        do {
            try await service.signOut()
            state = .signedOut
        } catch {
            AppLog.auth.error("Sign out failed: \(String(describing: error))")
        }
    }

    /// Deletes the remote account. Local data removal is handled by the caller
    /// so that the two halves can be reported to the user independently.
    func deleteAccount() async throws {
        try await service.deleteAccount()
        state = .signedOut
    }
}
