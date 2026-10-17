// ✅ GOOD: secrets go in the Keychain (encrypted by iOS, can be tied to this device only)
// 🍎 Apple platforms only (iOS app, iOS Playground). Not run in this guide's Linux test.
import Foundation
import Security

struct KeychainError: Error {
    let status: OSStatus
}

struct KeychainStore {
    let service: String                       // e.g. "com.mybank.auth"

    func save(_ data: Data, for account: String) throws {
        let query = baseQuery(account)
        SecItemDelete(query as CFDictionary)  // replace any old value

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly   // not in backups
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func read(_ account: String) throws -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        return result as? Data
    }

    func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

// Demo
let keychain = KeychainStore(service: "com.mybank.auth")
do {
    try keychain.save(Data("eyJhbGciOiJIUzI1NiJ9.refresh-token".utf8), for: "refreshToken")
    if let data = try keychain.read("refreshToken") {
        print("read back:", String(decoding: data, as: UTF8.self))
    }
    keychain.delete("refreshToken")
    print("after logout:", try keychain.read("refreshToken") == nil ? "deleted ✅" : "still there ❌")
} catch {
    print("Keychain error:", error)
}
