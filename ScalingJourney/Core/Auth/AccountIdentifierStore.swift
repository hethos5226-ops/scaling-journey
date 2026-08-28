import Foundation
import Security

/// Persists the account identifier that every local record is keyed to.
protocol AccountIdentifierStore: Sendable {
    func currentIdentifier() -> String?
    @discardableResult
    func createIdentifier() -> String
    func clear()
}

/// Keychain-backed identifier storage.
///
/// The Keychain rather than `UserDefaults` for two reasons: it is the right
/// place for anything session-shaped (auth tokens land here next), and it
/// survives the app being deleted and reinstalled, so a user who reinstalls
/// keeps the identifier their restored data is keyed to.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` keeps the value off
/// iCloud Keychain and off other devices, matching the privacy promise that
/// nothing leaves the device until sync is switched on.
struct KeychainAccountIdentifierStore: AccountIdentifierStore {
    private let service: String
    private let account = "primary-account-identifier"

    init(service: String = (Bundle.main.bundleIdentifier ?? "com.scalingjourney.ScalingJourney") + ".account") {
        self.service = service
    }

    func currentIdentifier() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }

        return value
    }

    @discardableResult
    func createIdentifier() -> String {
        let identifier = "device-" + UUID().uuidString
        guard let data = identifier.data(using: .utf8) else { return identifier }

        // Replace rather than add, so a stale item can never block creation.
        SecItemDelete(baseQuery() as CFDictionary)

        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            AppLog.auth.error("Keychain write failed with status \(status, privacy: .public)")
        }
        return identifier
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// In-memory identifier store for tests and previews.
final class InMemoryAccountIdentifierStore: AccountIdentifierStore, @unchecked Sendable {
    private let lock = NSLock()
    private var identifier: String?

    init(identifier: String? = nil) {
        self.identifier = identifier
    }

    func currentIdentifier() -> String? {
        lock.withLock { identifier }
    }

    @discardableResult
    func createIdentifier() -> String {
        lock.withLock {
            let value = "device-" + UUID().uuidString
            identifier = value
            return value
        }
    }

    func clear() {
        lock.withLock { identifier = nil }
    }
}
