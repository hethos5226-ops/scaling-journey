import XCTest
@testable import ScalingJourney

final class LocalAccountAuthenticationServiceTests: XCTestCase {
    func testSigningInCreatesAStableIdentifier() async throws {
        let service = LocalAccountAuthenticationService(store: InMemoryAccountIdentifierStore())

        let first = try await service.signIn(with: .device)
        let second = try await service.signIn(with: .device)

        XCTAssertEqual(first.identifier, second.identifier, "The identifier all data is keyed to must not change")
        XCTAssertEqual(first.provider, .device)
        XCTAssertTrue(first.isDeviceLocal)
    }

    func testRestoreSessionReturnsNilBeforeFirstSignIn() async {
        let service = LocalAccountAuthenticationService(store: InMemoryAccountIdentifierStore())
        let restored = await service.restoreSession()
        XCTAssertNil(restored)
    }

    func testRestoreSessionReturnsTheSameAccountAfterSignIn() async throws {
        let service = LocalAccountAuthenticationService(store: InMemoryAccountIdentifierStore())
        let created = try await service.signIn(with: .device)
        let restored = await service.restoreSession()
        XCTAssertEqual(restored?.identifier, created.identifier)
    }

    /// Signing out of a device-local account must not orphan the user's data.
    func testSignOutKeepsTheIdentifier() async throws {
        let store = InMemoryAccountIdentifierStore()
        let service = LocalAccountAuthenticationService(store: store)

        let account = try await service.signIn(with: .device)
        try await service.signOut()

        XCTAssertEqual(store.currentIdentifier(), account.identifier)
    }

    func testDeleteAccountClearsTheIdentifier() async throws {
        let store = InMemoryAccountIdentifierStore()
        let service = LocalAccountAuthenticationService(store: store)

        _ = try await service.signIn(with: .device)
        try await service.deleteAccount()

        XCTAssertNil(store.currentIdentifier())
    }

    /// Providers this build cannot serve must fail loudly rather than silently
    /// producing a local account under a cloud provider's name.
    func testCloudProvidersAreRejectedWhenNotConfigured() async {
        let service = LocalAccountAuthenticationService(store: InMemoryAccountIdentifierStore())
        do {
            _ = try await service.signIn(with: .email(address: "a@b.com", password: "hunter2"))
            XCTFail("Expected sign-in to fail")
        } catch let error as AuthError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOnlyDeviceProviderIsAdvertised() {
        let service = LocalAccountAuthenticationService(store: InMemoryAccountIdentifierStore())
        XCTAssertEqual(service.availableProviders, [.device])
    }
}

final class AppConfigurationTests: XCTestCase {
    /// A build with no backend configured must report that cleanly rather than
    /// producing a half-valid URL.
    func testUnconfiguredBackendIsReportedAsSuch() {
        let configuration = AppConfiguration(apiBaseURL: nil, googleClientID: nil)
        XCTAssertFalse(configuration.isBackendConfigured)
        XCTAssertFalse(configuration.isGoogleSignInConfigured)
    }

    func testConfiguredBackendIsReportedAsSuch() {
        let configuration = AppConfiguration(
            apiBaseURL: URL(string: "https://api.example.com"),
            googleClientID: "1234.apps.googleusercontent.com"
        )
        XCTAssertTrue(configuration.isBackendConfigured)
        XCTAssertTrue(configuration.isGoogleSignInConfigured)
    }
}

final class ChangeTintTests: XCTestCase {
    /// Without a goal the app takes no view on which direction is good.
    func testNoGoalMeansNeutral() {
        XCTAssertEqual(ChangeTint.forChange(-2, goalKilograms: nil, currentKilograms: 80), .neutral)
    }

    func testLosingTowardALowerGoalIsPositive() {
        // 82 -> 80 with a goal of 75: closer than it was.
        XCTAssertEqual(ChangeTint.forChange(-2, goalKilograms: 75, currentKilograms: 80), .towardGoal)
    }

    /// Gaining is progress for a user whose goal is above their current weight;
    /// the tint must not moralise about the direction.
    func testGainingTowardAHigherGoalIsPositive() {
        XCTAssertEqual(ChangeTint.forChange(2, goalKilograms: 90, currentKilograms: 80), .towardGoal)
    }

    func testMovingAwayFromTheGoalIsNotPositive() {
        XCTAssertEqual(ChangeTint.forChange(2, goalKilograms: 75, currentKilograms: 82), .awayFromGoal)
    }

    func testNegligibleChangeIsNeutral() {
        XCTAssertEqual(ChangeTint.forChange(0, goalKilograms: 75, currentKilograms: 80), .neutral)
    }
}
