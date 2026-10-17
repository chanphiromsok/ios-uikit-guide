// ✅ GOOD: the token itself is locked behind Face ID / Touch ID by the Keychain
// (❌ BAD would be: `if try await LAContext().evaluatePolicy(...) { read token from UserDefaults }`:
//  a hooking tool can force that `true`.)
// 🍎 iOS only. Add NSFaceIDUsageDescription to Info.plist. Not run in this guide's Linux test.
import Foundation
import LocalAuthentication
import Security

struct KeychainError: Error {
    let status: OSStatus
}

private let baseQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.mybank.auth",
    kSecAttrAccount as String: "refreshToken",
]

func saveRefreshToken(_ token: Data) throws {
    guard let access = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,              // invalidated if a new fingerprint or face is enrolled
        nil
    ) else { throw KeychainError(status: errSecParam) }

    SecItemDelete(baseQuery as CFDictionary)

    var item = baseQuery
    item[kSecValueData as String] = token
    item[kSecAttrAccessControl as String] = access
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError(status: status) }
}

/// Shows the Face ID prompt. Call it off the main thread: it blocks until the user responds.
func readRefreshToken() throws -> Data {
    let context = LAContext()
    context.localizedReason = "Unlock MyBank"

    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecUseAuthenticationContext as String] = context

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
    return data
}
