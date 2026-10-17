# 08 · Local storage

[← Index](../README.md) · [← Environments](07-environments.md) · [Next: Security →](09-security.md)

| Storage | Use for | React Native equivalent |
|---|---|---|
| `UserDefaults` | small, **non-sensitive** settings (theme, language, onboarding seen). It's an **unencrypted** plist. | AsyncStorage |
| **Keychain** | tokens, credentials, keys | react-native-keychain |
| Files (`FileManager`) | downloads, JSON caches. `Caches/` can be purged by iOS; `Application Support/` holds app data. | RNFS |
| Core Data | mature object graph and database built into iOS | WatermelonDB-ish |
| SwiftData | newer Swift-native layer over the same engine (iOS 17+) | – |
| SQLite via GRDB | big apps that want explicit SQL. Add SQLCipher for encryption. | SQLite libraries |
| `NSCache` | in-memory only; iOS evicts it under memory pressure | an in-memory map |

---

## 8.1 Tokens and secrets

### ❌ Bad: secrets in UserDefaults

<!-- example: examples/08-storage/01-token-storage-bad.swift -->
```swift
// ❌ BAD: secrets in UserDefaults → a plain, unencrypted file inside the app's folder
// Run: swift examples/08-storage/01-token-storage-bad.swift
import Foundation

guard let defaults = UserDefaults(suiteName: "guide-demo-bad") else { fatalError("no defaults") }

defaults.set("eyJhbGciOiJIUzI1NiJ9.refresh-token", forKey: "refreshToken")   // ❌
defaults.set("1234", forKey: "pin")                                          // ❌❌

print("refreshToken:", defaults.string(forKey: "refreshToken") ?? "nil")
print("pin:", defaults.string(forKey: "pin") ?? "nil")
print("On iOS this is Library/Preferences/<bundle-id>.plist: readable in device backups and on jailbroken phones.")

defaults.removePersistentDomain(forName: "guide-demo-bad")                  // clean up this demo
```

**Output**

```text
refreshToken: eyJhbGciOiJIUzI1NiJ9.refresh-token
pin: 1234
On iOS this is Library/Preferences/<bundle-id>.plist: readable in device backups and on jailbroken phones.
```
<!-- /example -->

### ✅ Good: the Keychain (🍎 Apple platforms)

<!-- snippet: examples/08-storage/apple-only/KeychainStore.swift -->
```swift
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
```
<!-- /snippet -->

> 🍎 Not compiled in this guide's Linux test run. To lock the token behind Face ID, see [09 · Security](09-security.md#93-biometric-login).

---

## 8.2 Settings

### ❌ Bad: string keys scattered everywhere

<!-- example: examples/08-storage/02-settings-bad.swift -->
```swift
// ❌ BAD: "stringly-typed" UserDefaults keys scattered around the app → one typo = a silent bug
// Run: swift examples/08-storage/02-settings-bad.swift
import Foundation

guard let defaults = UserDefaults(suiteName: "guide-demo-settings-bad") else { fatalError("no defaults") }

// Settings screen
defaults.set(true, forKey: "isBalanceHidden")

// Home screen, written by another developer
let hidden = defaults.bool(forKey: "isBalancehidden")      // typo: lowercase "h"
print("balance hidden?", hidden, "→ the balance is shown on the home screen 😱")

defaults.removePersistentDomain(forName: "guide-demo-settings-bad")
```

**Output**

```text
balance hidden? false → the balance is shown on the home screen 😱
```
<!-- /example -->

### ✅ Good: one typed settings wrapper

<!-- example: examples/08-storage/02-settings-good.swift -->
```swift
// ✅ GOOD: one typed settings wrapper → keys live in one place, values have real types, easy to reset on logout
// Run: swift examples/08-storage/02-settings-good.swift
import Foundation

struct AppSettings {
    enum Language: String { case english = "en", khmer = "km" }

    private enum Key {
        static let isBalanceHidden = "settings.isBalanceHidden"
        static let language = "settings.language"
        static let all = [isBalanceHidden, language]
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isBalanceHidden: Bool {
        get { defaults.bool(forKey: Key.isBalanceHidden) }
        nonmutating set { defaults.set(newValue, forKey: Key.isBalanceHidden) }
    }

    var language: Language {
        get { defaults.string(forKey: Key.language).flatMap(Language.init(rawValue:)) ?? .english }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    func reset() { Key.all.forEach(defaults.removeObject(forKey:)) }   // call on logout
}

// A separate suite keeps this demo (and your unit tests) away from real settings
guard let demoDefaults = UserDefaults(suiteName: "guide-demo-settings-good") else { fatalError("no defaults") }
let settings = AppSettings(defaults: demoDefaults)

settings.isBalanceHidden = true
settings.language = .khmer
print("balance hidden?", settings.isBalanceHidden)
print("language:", settings.language)

settings.reset()
print("after logout → balance hidden?", settings.isBalanceHidden, "| language:", settings.language)
demoDefaults.removePersistentDomain(forName: "guide-demo-settings-good")
```

**Output**

```text
balance hidden? true
language: khmer
after logout → balance hidden? false | language: english
```
<!-- /example -->

---

## Banking rules

- **Store as little as possible.** The safest data is data you never saved.
- Encrypt any local database (GRDB + SQLCipher).
- Write sensitive files with `.completeFileProtection`.
- Exclude sensitive files from iCloud backup (`isExcludedFromBackup = true`).
- **Wipe everything on logout:** Keychain items, caches, the settings that belong to the user.
- **Keychain items survive deleting the app** (on a real device). On first launch, if a "has launched before" flag is missing from `UserDefaults`, clear the Keychain. Otherwise a reinstalled app can find the previous user's token.

**Practice**

- [ ] Add a `lastLoginPhone` setting to `AppSettings` (used to prefill the login field). Is it OK for UserDefaults? (Think: is a phone number sensitive?)
- [ ] Write the "first launch after reinstall → clear Keychain" logic.

---

## Alternatives and trade-offs

**Keychain**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| Security framework directly (this guide) | no dependency, every option available | verbose C-style API | default for banking (less to audit) |
| Valet (Square) | simple API, Secure Enclave + biometric options | dependency | you want a well-designed wrapper |
| KeychainAccess / SimpleKeychain | very short API | check maintenance status; dependency | small apps |

**Databases**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| GRDB (SQLite) | explicit SQL, great concurrency, migrations, SQLCipher encryption | you write SQL and schemas | banking/offline data that must be encrypted |
| Core Data | built-in, mature, iCloud sync, Xcode tooling | complex threading rules, old API style | existing apps; Apple-ecosystem features |
| SwiftData | Swift-native, simple macros (`@Model`) | iOS 17+, younger, fewer escape hatches | new apps with a high minimum iOS version |
| Realm | easy object API | MongoDB deprecated its Device SDKs in 2024; long-term risk | existing Realm apps only |
| Files + `Codable` | simplest for small caches | no queries, no partial updates | small JSON caches (non-sensitive) |

**Settings**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| Typed wrapper over `UserDefaults` (this guide) | no dependency, testable with a suite | a little code per key | default |
| Defaults (sindresorhus) | typed keys, observation | dependency | many settings |
| `@AppStorage` | one line in SwiftUI | SwiftUI only | SwiftUI screens |

---

[← Index](../README.md) · [← Environments](07-environments.md) · [Next: Security →](09-security.md)
