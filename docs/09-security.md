# 09 · Security for banking apps

[← Index](../README.md) · [← Local storage](08-local-storage.md) · [Next: Performance and rendering →](10-performance-and-rendering.md)

The industry checklist is **OWASP MASVS / MASTG** ([mas.owasp.org](https://mas.owasp.org)), and banks audit against it. Cambodian banks also follow the National Bank of Cambodia's technology risk guidelines.

| Area | What to do |
|---|---|
| Secrets / tokens | **Keychain** only, `...ThisDeviceOnly`. Never `UserDefaults` ([08](08-local-storage.md)). |
| Biometrics | **Lock the Keychain item behind biometry**; don't trust a `Bool` from `evaluatePolicy` |
| Crypto keys | Secure Enclave via CryptoKit (`SecureEnclave.P256`) |
| Network | ATS (TLS) + **pinning** (`NSPinnedDomains`), with a backup pin |
| App integrity | **App Attest** (`DCAppAttestService`) so the server knows it's your genuine app |
| Files | `.completeFileProtection` |
| Screen | privacy cover in the app switcher; watch `sceneCaptureState` for recording |
| Input | `isSecureTextEntry`, block third-party keyboards, custom PIN pad, clear the pasteboard |
| Logs | never log tokens, PINs or full account numbers |
| Transfers | **idempotency key** per transfer; disable the button while sending |
| Session | short-lived access token, refresh token in Keychain, auto-logout after inactivity |
| Hardening | jailbreak and debugger detection, obfuscation: speed bumps, not walls |
| **Golden rule** | **anything in the app can be extracted.** The server is the real authority. |

---

## 9.1 Logging

### ❌ Bad

<!-- example: examples/09-security/01-logging-bad.swift -->
```swift
// ❌ BAD: logging secrets and personal data → they end up in device logs, crash reports and analytics
// Run: swift examples/09-security/01-logging-bad.swift

let accessToken = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.sig"
let fromAccount = "000123456"
let toAccount = "000987654"
let pin = "1234"

print("POST /v1/transfers Authorization: Bearer \(accessToken)")
print("transfer $20.00 from \(fromAccount) to \(toAccount), pin=\(pin)")
```

**Output**

```text
POST /v1/transfers Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.sig
transfer $20.00 from 000123456 to 000987654, pin=1234
```
<!-- /example -->

### ✅ Good

<!-- example: examples/09-security/01-logging-good.swift -->
```swift
// ✅ GOOD: redact before logging; never log PINs at all
// Run: swift examples/09-security/01-logging-good.swift
// On iOS, send the message to os.Logger:  Logger.transfer.info("\(message, privacy: .public)")
// or log raw values with `privacy: .private` so they are hidden in production logs.

enum Redact {
    static func account(_ number: String) -> String {
        let digits = number.filter(\.isNumber)
        guard digits.count > 4 else { return String(repeating: "•", count: digits.count) }
        return String(repeating: "•", count: digits.count - 4) + digits.suffix(4)
    }

    static func token(_ token: String) -> String {
        token.isEmpty ? "<none>" : "<redacted, \(token.count) chars>"
    }
}

let accessToken = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.sig"
let fromAccount = "000123456"
let toAccount = "000987654"

print("POST /v1/transfers Authorization: \(Redact.token(accessToken))")
print("transfer $20.00 from \(Redact.account(fromAccount)) to \(Redact.account(toAccount))")
```

**Output**

```text
POST /v1/transfers Authorization: <redacted, 44 chars>
transfer $20.00 from •••••3456 to •••••7654
```
<!-- /example -->

On iOS use `os.Logger`. Interpolated values are private by default in release logs. Mark only safe values as `.public`:

```swift
import OSLog

extension Logger {
    static let transfer = Logger(subsystem: "com.mybank.app", category: "transfer")
}

Logger.transfer.info("transfer to \(Redact.account(toAccount), privacy: .public) amount \(amount, privacy: .private)")
```

---

## 9.2 Idempotent transfers

**Why it matters:**
- **The scenario:** on a bad mobile network, the server can move the money while the response gets lost. The app sees a timeout and retries.
- **The risk:** without an idempotency key, the retry is a **second transfer**.
- **Interviewers ask this.**

### ❌ Bad

<!-- example: examples/09-security/02-idempotency-bad.swift -->
```swift
// ❌ BAD: retrying a transfer after a timeout without an idempotency key → the customer pays twice
// Run: swift examples/09-security/02-idempotency-bad.swift
import Foundation

struct Timeout: Error {}

// Fake bank server. The FIRST response is lost on the way back (bad mobile network):
// the money has moved, but the app only sees a timeout.
actor FakeBankServer {
    private(set) var balance: Decimal = 100
    private var receiptsByKey: [String: String] = [:]
    private var receiptCount = 0
    private var loseNextResponse = true

    func transfer(amount: Decimal, idempotencyKey: String?) throws -> String {
        if let idempotencyKey, let receipt = receiptsByKey[idempotencyKey] {
            return receipt                                   // already done → do NOT charge again
        }
        balance -= amount
        receiptCount += 1
        let receipt = "RCPT-\(receiptCount)"
        if let idempotencyKey { receiptsByKey[idempotencyKey] = receipt }
        if loseNextResponse {
            loseNextResponse = false
            throw Timeout()
        }
        return receipt
    }
}

func sendTransfer(_ amount: Decimal, server: FakeBankServer) async throws -> String {
    for attempt in 1...2 {
        do {
            return try await server.transfer(amount: amount, idempotencyKey: nil)   // ❌ no key
        } catch is Timeout {
            print("attempt \(attempt): timeout → retrying…")
        }
    }
    throw Timeout()
}

let server = FakeBankServer()
let receipt = try await sendTransfer(20, server: server)
print("receipt:", receipt)
print("balance: $\(await server.balance)  (started at $100, sent $20) 😱 charged twice")
```

**Output**

```text
attempt 1: timeout → retrying…
receipt: RCPT-2
balance: $60  (started at $100, sent $20) 😱 charged twice
```
<!-- /example -->

### ✅ Good

<!-- example: examples/09-security/02-idempotency-good.swift -->
```swift
// ✅ GOOD: one idempotency key per transfer, reused on every retry → the server charges once
// Run: swift examples/09-security/02-idempotency-good.swift
import Foundation

struct Timeout: Error {}

// Fake bank server. The FIRST response is lost on the way back (bad mobile network):
// the money has moved, but the app only sees a timeout.
actor FakeBankServer {
    private(set) var balance: Decimal = 100
    private var receiptsByKey: [String: String] = [:]
    private var receiptCount = 0
    private var loseNextResponse = true

    func transfer(amount: Decimal, idempotencyKey: String?) throws -> String {
        if let idempotencyKey, let receipt = receiptsByKey[idempotencyKey] {
            return receipt                                   // already done → do NOT charge again
        }
        balance -= amount
        receiptCount += 1
        let receipt = "RCPT-\(receiptCount)"
        if let idempotencyKey { receiptsByKey[idempotencyKey] = receipt }
        if loseNextResponse {
            loseNextResponse = false
            throw Timeout()
        }
        return receipt
    }
}

func sendTransfer(_ amount: Decimal, server: FakeBankServer) async throws -> String {
    let idempotencyKey = UUID().uuidString            // created ONCE, when the user taps "Confirm"
    for attempt in 1...2 {
        do {
            return try await server.transfer(amount: amount, idempotencyKey: idempotencyKey)
        } catch is Timeout {
            print("attempt \(attempt): timeout → retrying with the same key…")
        }
    }
    throw Timeout()
}

let server = FakeBankServer()
let receipt = try await sendTransfer(20, server: server)
print("receipt:", receipt)
print("balance: $\(await server.balance)  (started at $100, sent $20) ✅ charged once")
```

**Output**

```text
attempt 1: timeout → retrying with the same key…
receipt: RCPT-1
balance: $80  (started at $100, sent $20) ✅ charged once
```
<!-- /example -->

Also:
- Disable the "Confirm" button while the request runs.
- On a timeout, ask the server "did transfer X happen?" before letting the user try again.

---

## 9.3 Biometric login

❌ **Bad:** `if try await LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, …) { readTokenFromUserDefaults() }`. A hooking tool on a jailbroken phone can force that `true`, and the token isn't protected at all.

✅ **Good:** the Keychain itself refuses to return the token without Face ID / Touch ID (🍎):

<!-- snippet: examples/09-security/apple-only/BiometricKeychain.swift -->
```swift
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
```
<!-- /snippet -->

---

## 9.4 Privacy cover and keyboards

❌ **Bad:** nothing. The app switcher shows the last screen, balance included, and a third-party keyboard can log every PIN digit.

✅ **Good** (🍎):

<!-- snippet: examples/09-security/apple-only/PrivacyCover.swift -->
```swift
// ✅ GOOD: hide balances in the app switcher, and block third-party keyboards
// 🍎 iOS only. Not run in this guide's Linux test.
import UIKit

// SceneDelegate.swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var privacyCover: UIView?

    func sceneWillResignActive(_ scene: UIScene) {
        guard let window, privacyCover == nil else { return }
        let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        cover.frame = window.bounds
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(cover)
        privacyCover = cover
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        privacyCover?.removeFromSuperview()
        privacyCover = nil
    }
}

// AppDelegate.swift
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        extensionPointIdentifier != .keyboard            // only the system keyboard can see the PIN
    }
}
```
<!-- /snippet -->

---

## 9.5 Certificate pinning

❌ **Bad:** trusting any certificate the phone trusts. A malicious or corporate root CA can read all traffic.

✅ **Good:** pin your CA's public key in `Info.plist` (🍎, no code needed):

<!-- snippet: examples/09-security/apple-only/Pinning-Info.plist -->
```xml
<!-- Certificate pinning with no code: add to Info.plist (iOS 14+).
     Pin the CA (or include a backup key) so a certificate rotation doesn't lock every user out. -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSPinnedDomains</key>
    <dict>
        <key>api.mybank.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSPinnedCAIdentities</key>
            <array>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string>BASE64_SHA256_OF_CA_PUBLIC_KEY=</string>
                </dict>
            </array>
        </dict>
    </dict>
</dict>
```
<!-- /snippet -->

**Pinning blocks debugging proxies** (Proxyman, Charles). Use a separate Dev `Info.plist` (set `INFOPLIST_FILE` per configuration) so only Prod pins.

> 🍎 Files in `apple-only/` were not compiled in this guide's Linux test run.

**Practice**

- [ ] Add a `Redact.phone(_:)` that turns `012345678` into `012•••678`, and use it in the logging example.
- [ ] In the idempotency example, lose the response twice. Does the good version still charge once?
- [ ] Read the OWASP MASVS "Storage" and "Network" sections.

---

## Alternatives and trade-offs

| Need | Option | ✅ Strengths | ⚠️ Trade-offs |
|---|---|---|---|
| Pinning | `NSPinnedDomains` (this guide) | no code, enforced by the system | no failure reporting; fixed in `Info.plist` |
| Pinning | `URLSessionDelegate` (manual) | full control, can report failures | easy to get wrong; you own the crypto checks |
| Pinning | Alamofire `ServerTrustManager` / TrustKit | tested implementations; TrustKit reports pin failures | dependencies |
| Jailbreak / tamper detection | DIY checks | free, no dependency | trivial to bypass with hooking tools |
| Jailbreak / tamper detection | IOSSecuritySuite (open source) | many checks in one package | still bypassable; false positives possible |
| Jailbreak / tamper detection | Commercial runtime protection (Promon SHIELD, Guardsquare iXGuard, Appdome…) | obfuscation, anti-hooking, anti-debug; auditors recognise them | licence cost; build integration; can slow builds |
| Device integrity | App Attest (`DCAppAttestService`) | Apple-signed proof that it's your genuine app | server work; not on old devices/Simulator |
| Device integrity | DeviceCheck | 2 bits per device stored by Apple (e.g. "bonus already used") | very limited |
| Biometrics | LocalAuthentication + Keychain access control (this guide) | the OS enforces it | needs a passcode-protected device; plan a PIN fallback |

---

[← Index](../README.md) · [← Local storage](08-local-storage.md) · [Next: Performance and rendering →](10-performance-and-rendering.md)
