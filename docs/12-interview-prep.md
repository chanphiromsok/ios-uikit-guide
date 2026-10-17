# 12 · Cambodian bank interview prep

[← Index](../README.md) · [← Devtools](11-devtools.md) · [Next: Capstone →](13-capstone.md)

> This is the usual pattern at banks and fintechs in Phnom Penh (ABA, ACLEDA, Wing, Canadia, Prince, Chip Mong, Sathapana and others), plus what banking iOS interviews ask everywhere. It isn't inside information: processes differ, so ask HR about their stages on the first call.

## The process

| Stage | Who | What happens |
|---|---|---|
| 1. CV screening | HR | CV in English; a GitHub link or an App Store app helps a lot |
| 2. Phone screen | HR, often in Khmer | experience, notice period, salary expectation, English check |
| 3. Technical test | iOS team | a **take-home app** (2–5 days) or an **on-site written/online test** |
| 4. Technical interview (1–2 rounds) | iOS lead, seniors | walk through your test; Swift, UIKit, architecture, security; live coding |
| 5. Manager round | Head of Digital / CTO | experience, teamwork, goals |
| 6. Offer | HR | salary (usually USD), probation (often 3 months), benefits, sometimes a background check and an NDA |

Technical words stay in English even in a Khmer interview, so **practise explaining concepts out loud in English**.

---

## Technical questions (click to reveal; each links to the runnable example)

<details>
<summary><b>struct vs class: when do you use each?</b></summary>

`struct` is a value type, copied on assignment. Use it by default for models and ViewData. `class` is a reference type with identity and inheritance; use it for UIKit views, VCs, and shared objects with a lifecycle. → [02 · 2.1](02-swift-fundamentals.md#21-struct-vs-class)
</details>

<details>
<summary><b>What is a retain cycle? weak vs unowned?</b></summary>

Two objects hold each other strongly, so ARC never frees them. It's common with closures capturing `self`, and with strong delegates. Fix it with `[weak self]` or `weak var delegate`. `weak` becomes `nil`; `unowned` crashes if used after being freed. → [02 · 2.5](02-swift-fundamentals.md#25-retain-cycles-and-weak-self), [05 · 5.5](05-uikit.md#55-delegates)
</details>

<details>
<summary><b>Completion handlers + GCD vs async/await?</b></summary>

With GCD you pass a closure, hop to `DispatchQueue.main` yourself, wrap errors in `Result`, and must call the completion exactly once. The compiler doesn't check any of that. `async/await` reads top to bottom, uses `throw`, and gets main-thread safety from `@MainActor`. Bridge old APIs with `withCheckedThrowingContinuation`. → [03](03-concurrency.md)
</details>

<details>
<summary><b>What is an actor? What does @MainActor do?</b></summary>

An actor lets one caller at a time touch its state, which prevents data races; you `await` to access it. `@MainActor` guarantees main-thread execution, which UIKit requires. → [03 · 3.4](03-concurrency.md#34-shared-mutable-state), [3.5](03-concurrency.md#35-ui-updates-on-the-main-thread)
</details>

<details>
<summary><b>VC lifecycle: where do you start a network call?</b></summary>

`viewDidLoad` for the first load (it runs once). `viewWillAppear` only if the data must refresh on every appearance, ideally through a cache. Cancel in `viewDidDisappear` when `isMovingFromParent`. → [05 · 5.2](05-uikit.md#52-view-controller-lifecycle)
</details>

<details>
<summary><b>frame vs bounds?</b></summary>

`frame` is in the superview's coordinates; `bounds` is in the view's own coordinates (origin usually 0,0). A scroll view's `contentOffset` is its `bounds.origin`. A transform changes `frame`, not `bounds`. → [05 · 5.3](05-uikit.md#53-auto-layout)
</details>

<details>
<summary><b>A reused cell shows the wrong image. Why?</b></summary>

Cell reuse: an old download finishes after the cell started showing another row. Cancel the task and reset the image in `prepareForReuse`, and check for cancellation before setting the image. → [05 · 5.4](05-uikit.md#54-lists-and-cell-reuse)
</details>

<details>
<summary><b>How do you pass data from a list to a detail screen?</b></summary>

- **The id:** pass it through a **non-optional** `init`, so the screen can't exist without one.
- **A placeholder:** also pass the summary the list already has, to show instantly.
- **The fetch:** load the full record by id.
- **Cleanup:** cancel when the user leaves.
- **Stale responses:** if the id can change, cancel the old request and ignore responses whose id doesn't match.
- **Deep links:** they parse the id first and never call the API without one.

→ [05 · 5.8](05-uikit.md#58-list--detail-pass-the-id-fetch-by-id)
</details>

<details>
<summary><b>MVVM: how does the ViewModel tell the VC to update?</b></summary>

Through Combine `@Published` + `sink`, an `onChange` closure, or `@Observable` (tracked automatically by UIKit in iOS 26). The ViewModel never imports UIKit, so it's unit-testable. → [06 · 6.2](06-architecture.md#62-mvvm--coordinator)
</details>

<details>
<summary><b>Design the money transfer flow.</b></summary>

Choose account → amount → confirm → PIN/OTP → receipt. Key points:
- An **idempotency key** per transfer.
- The button disabled while sending.
- On timeout, check the status with the server before retrying.
- Invalidate the balance cache after success.
- Don't keep the PIN in memory.

→ [09 · 9.2](09-security.md#92-idempotent-transfers)
</details>

<details>
<summary><b>The access token expires while 5 requests are running.</b></summary>

Refresh **once**: an actor holds the in-flight refresh `Task`, the others await it, then everyone retries with the new token. If a late request reports the old token, return the current one without refreshing again. If the refresh fails, log out. → [04 · 4.4](04-networking-and-data.md#44-token-refresh-the-classic-senior-question)
</details>

<details>
<summary><b>Three screens load the same data at launch. How many requests?</b></summary>

It should be one. Without de-duplication, a cache still sends three, because all three miss at the same time. Keep an in-flight `Task` in an actor and share it. → [04 · 4.3](04-networking-and-data.md#43-caching-and-invalidation)
</details>

<details>
<summary><b>Where do you store the token? Why not UserDefaults?</b></summary>

In the Keychain (`...ThisDeviceOnly`), optionally behind biometry. `UserDefaults` is an unencrypted plist, readable in backups and on jailbroken devices. → [08 · 8.1](08-local-storage.md#81-tokens-and-secrets)
</details>

<details>
<summary><b>SSL pinning: what breaks when the certificate changes?</b></summary>

Every request fails if the app doesn't know the new key. Pin the CA or include a backup pin, and plan rotation with the backend team. → [09 · 9.5](09-security.md#95-certificate-pinning)
</details>

<details>
<summary><b>How do you implement biometric login properly?</b></summary>

Store the refresh token in a Keychain item with `.biometryCurrentSet` access control, so reading it triggers Face ID. The item is invalidated when new biometrics are enrolled. Don't rely on `evaluatePolicy` returning `true`. → [09 · 9.3](09-security.md#93-biometric-login)
</details>

<details>
<summary><b>Dev vs Prod: how do you set it up?</b></summary>

`.xcconfig` per environment → values in `Info.plist` → one validated `AppEnvironment` at launch. Separate schemes and bundle IDs; secrets in a git-ignored `Secrets.xcconfig` created by CI. Debug/Release ≠ Dev/Prod. → [07](07-environments.md)
</details>

<details>
<summary><b>Scrolling is laggy. What do you do?</b></summary>

Profile on a device with Time Profiler + Animation Hitches. Typical fixes:
- Move formatting, parsing and image decoding off the main thread (or do them once).
- Pre-build ViewData.
- Add a `shadowPath`, and avoid offscreen rendering.

→ [10](10-performance-and-rendering.md)
</details>

<details>
<summary><b>How do you find a memory leak?</b></summary>

Open and close the screen several times, then use the Memory Graph Debugger to find leftover instances and who holds them. `deinit` prints are a quick check. → [11](11-devtools.md#memory-graph-find-retain-cycles)
</details>

---

## Cambodia-specific topics

1. **KHQR / Bakong:** scan-to-pay.
   - Camera permission, and what happens when it's denied.
   - Scanning with AVFoundation or VisionKit `DataScannerViewController`.
   - Parsing the EMVCo TLV payload and validating the CRC.
   - Confirming merchant and amount.
   - A "My QR" screen.
   - Tags: `53` currency (`840` USD, `116` KHR), `54` amount, `58` country, `59` merchant, `60` city, `63` CRC.
2. **USD and KHR:** `Decimal`; USD with cents, KHR usually without (`50,000 ៛`). → [04 · 4.2](04-networking-and-data.md#42-dto--domain--viewdata)
3. **Khmer language support:**
   - An in-app English/Khmer switch.
   - Khmer fonts.
   - **Clipped text:** Khmer stacks vowels and subscripts, so labels need extra line height.
   - Line breaking: Khmer has no spaces between words.
   - Test with `-AppleLanguages (km)`.
4. **Older iPhones and slow networks:** minimum iOS version; offline and retry states; the Network Link Conditioner.
5. **Transaction push notifications:** encrypted payloads decrypted in a Notification Service Extension.

## Live coding practice (🐧)

Try each one yourself first, then compare:

<!-- example: examples/12-interview/live-coding.swift -->
```swift
// 🧑‍💻 Interview live-coding practice: solutions + self-checks. Try each one yourself first!
// Run: swift examples/12-interview/live-coding.swift
import Foundation

// 1. Mask an account number: "000123456" → "•••••3456"
func maskAccount(_ number: String) -> String {
    let digits = number.filter(\.isNumber)
    guard digits.count > 4 else { return digits }
    return String(repeating: "•", count: digits.count - 4) + digits.suffix(4)
}

// 2. Group thousands without NumberFormatter: 1250000 → "1,250,000"
func groupThousands(_ n: Int) -> String {
    let digits = String(n.magnitude)
    let count = digits.count
    var out = ""
    for (i, ch) in digits.enumerated() {
        if i > 0 && (count - i) % 3 == 0 { out.append(",") }
        out.append(ch)
    }
    return n < 0 ? "-" + out : out
}

// 3. Validate a Cambodian mobile number (simplified rule): +855 12 345 678 or 012 345 678
func isCambodianMobile(_ input: String) -> Bool {
    var digits = input.filter(\.isNumber)
    if digits.hasPrefix("855") { digits = "0" + digits.dropFirst(3) }
    return digits.hasPrefix("0")
        && (9...10).contains(digits.count)
        && digits.dropFirst().first != "0"
}

// 4. Parse an EMVCo / KHQR payload: TAG(2) LENGTH(2) VALUE… (simplified: ASCII only)
func parseTLV(_ payload: String) -> [String: String]? {
    var result: [String: String] = [:]
    var index = payload.startIndex
    while index < payload.endIndex {
        guard let tagEnd = payload.index(index, offsetBy: 2, limitedBy: payload.endIndex),
              let lengthEnd = payload.index(tagEnd, offsetBy: 2, limitedBy: payload.endIndex),
              let length = Int(payload[tagEnd..<lengthEnd]),
              let valueEnd = payload.index(lengthEnd, offsetBy: length, limitedBy: payload.endIndex)
        else { return nil }
        result[String(payload[index..<tagEnd])] = String(payload[lengthEnd..<valueEnd])
        index = valueEnd
    }
    return result
}

// 5. KHQR checksum: CRC-16/CCITT-FALSE over everything up to and including "6304"
func crc16CCITTFalse(_ data: Data) -> UInt16 {
    var crc: UInt16 = 0xFFFF
    for byte in data {
        crc ^= UInt16(byte) << 8
        for _ in 0..<8 {
            crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
        }
    }
    return crc
}

func hasValidCRC(_ payload: String) -> Bool {
    guard payload.count > 8, payload.dropLast(4).hasSuffix("6304") else { return false }
    guard let expected = UInt16(payload.suffix(4), radix: 16) else { return false }
    return crc16CCITTFalse(Data(payload.dropLast(4).utf8)) == expected
}

// ── Self-checks ─────────────────────────────────────────────────────────────────────
func check(_ name: String, _ condition: Bool) { print(condition ? "✅" : "❌", name) }

check("mask 000123456", maskAccount("000123456") == "•••••3456")
check("mask with spaces", maskAccount("000 123 456") == "•••••3456")
check("group 1250000", groupThousands(1_250_000) == "1,250,000")
check("group -999", groupThousands(-999) == "-999")
check("group 1000", groupThousands(1_000) == "1,000")
check("+855 12 345 678 is valid", isCambodianMobile("+855 12 345 678"))
check("012345678 is valid", isCambodianMobile("012345678"))
check("12345 is invalid", !isCambodianMobile("12345"))
check("CRC check value of \"123456789\" is 0x29B1", crc16CCITTFalse(Data("123456789".utf8)) == 0x29B1)

// Build a KHQR-shaped payload (simplified), then parse and validate it
func tlv(_ tag: String, _ value: String) -> String { tag + String(format: "%02d", value.count) + value }

var payload = tlv("00", "01") + tlv("01", "12") + tlv("52", "5999") + tlv("53", "116") + tlv("54", "50000")
    + tlv("58", "KH") + tlv("59", "Lucky Market") + tlv("60", "Phnom Penh") + "6304"
payload += String(format: "%04X", crc16CCITTFalse(Data(payload.utf8)))

print("\nKHQR payload:", payload)
if let tags = parseTLV(payload) {
    let currency = tags["53"] == "116" ? "KHR" : (tags["53"] == "840" ? "USD" : "?")
    print("merchant: \(tags["59"] ?? "?"), city: \(tags["60"] ?? "?"), amount: \(tags["54"] ?? "?") \(currency)")
}
check("valid payload passes the CRC check", hasValidCRC(payload))

let tampered = payload.replacingOccurrences(of: "540550000", with: "540590000")   // 50000 → 90000
check("tampered amount fails the CRC check", !hasValidCRC(tampered))
```

**Output**

```text
✅ mask 000123456
✅ mask with spaces
✅ group 1250000
✅ group -999
✅ group 1000
✅ +855 12 345 678 is valid
✅ 012345678 is valid
✅ 12345 is invalid
✅ CRC check value of "123456789" is 0x29B1

KHQR payload: 0002010102125204599953031165405500005802KH5912Lucky Market6010Phnom Penh6304016E
merchant: Lucky Market, city: Phnom Penh, amount: 50000 KHR
✅ valid payload passes the CRC check
✅ tampered amount fails the CRC check
```
<!-- /example -->

Also practise: debounce a search field, reverse a string, palindrome check, valid parentheses, two-sum.

## Take-home checklist

- [ ] MVVM (or similar), with no API calls in the VC
- [ ] loading, error, empty and retry states
- [ ] no force unwraps; errors handled
- [ ] unit tests for the ViewModel and mapping, with a mocked API (copy the style of [BankKit](../examples/06-architecture/BankKit))
- [ ] UI in code with Auto Layout; works on small and large iPhones
- [ ] README: how to run, decisions, what you'd improve
- [ ] clean git history with small commits

## Behavioral questions (often in Khmer)

- Tell me about yourself.
- **Why our bank?** Download their app before the interview, use it, and mention one thing you like and one thing you'd improve.
- Tell me about the hardest bug you've fixed.
- Tell me about a disagreement with a designer, QA or a teammate.
- Something broke in production. What did you do?
- Where do you see yourself in 3–5 years?
- What salary do you expect? Research first on CamHR, BongThom and LinkedIn, and by asking local developers.

**Moving from React Native:**
- Be honest that native iOS is new to you.
- Show the capstone running on a phone.
- Mention any iOS-native work you've already done: native modules, Live Activities, widgets.
- Some banks and fintechs use Flutter or React Native, so ask about their stack.

## Questions to ask them

- Is the app built in-house or by a vendor?
- How much is UIKit and how much is SwiftUI?
- What's the minimum iOS version?
- How often do you release?
- How do code review and testing work?
- How big is the iOS team?

---

## Alternatives and trade-offs (KHQR scanning)

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| VisionKit `DataScannerViewController` | a few lines, live highlighting, handles focus and guidance | iOS 16+ and A12 chip or newer; check `isSupported` / `isAvailable` | modern minimum iOS |
| AVFoundation (`AVCaptureMetadataOutput`) | works on every device, full control of UI and torch | more code (session, preview layer, permissions) | older devices, custom scanner UI |
| Vision (`VNDetectBarcodesRequest`) on photos | scan a QR from a screenshot or the photo library | not live by itself | "Scan from gallery" button |
| Google ML Kit | cross-platform consistency with Android | third-party SDK and size | the bank shares scanning logic with Android |

---

[← Index](../README.md) · [← Devtools](11-devtools.md) · [Next: Capstone →](13-capstone.md)
