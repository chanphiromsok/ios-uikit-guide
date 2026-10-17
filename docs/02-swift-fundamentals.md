# 02 · Swift fundamentals

[← Index](../README.md) · [← Setup](01-setup.md) · [Next: Concurrency →](03-concurrency.md)

All examples here are 🐧: they run anywhere Swift runs.

| Topic | Bad | Good |
|---|---|---|
| [2.1 struct vs class](#21-struct-vs-class) | class for a model | struct |
| [2.2 Optionals](#22-optionals) | force unwrap `!` | `??`, `guard let`, `if let` |
| [2.3 Screen state](#23-screen-state-with-an-enum) | many booleans | one `enum` |
| [2.4 Money](#24-money-decimal-never-double) | `Double` | `Decimal` |
| [2.5 Retain cycles](#25-retain-cycles-and-weak-self) | strong `self` in closures | `[weak self]` |
| [2.6 Errors](#26-error-handling) | `try?` swallows errors | specific errors + `do/catch` |
| [2.7 Dependency injection](#27-dependency-injection) | singleton inside | protocol in `init` |
| [2.8 JSON](#28-json-with-codable) | `[String: Any]` + `as!` | `Codable` |

---

## 2.1 struct vs class

**Why it matters:**
- A `class` is shared: two variables can point to the **same** object, so a change in one place silently changes the other.
- A `struct` is **copied** on assignment.
- Use `struct` by default for models, DTOs and ViewData. Use `class` for identity, inheritance and UIKit (`UIView` and `UIViewController` are classes).

### ❌ Bad

<!-- example: examples/02-swift/01-struct-vs-class-bad.swift -->
```swift
// ❌ BAD: a class for a simple model → shared, surprising changes
// Run: swift examples/02-swift/01-struct-vs-class-bad.swift
import Foundation

final class TransferDraft {
    var amount: Decimal
    var toAccount: String

    init(amount: Decimal, toAccount: String) {
        self.amount = amount
        self.toAccount = toAccount
    }
}

let original = TransferDraft(amount: 100, toAccount: "000123456")
let edited = original              // NOT a copy: both names point to the SAME object
edited.amount = 5_000              // the user edits the draft on the next screen…

print("original amount:", original.amount)   // 5000 😱 the "original" changed too
print("edited amount:  ", edited.amount)
```

**Output**

```text
original amount: 5000
edited amount:   5000
```
<!-- /example -->

### ✅ Good

<!-- example: examples/02-swift/01-struct-vs-class-good.swift -->
```swift
// ✅ GOOD: a struct for models → every assignment is an independent copy
// Run: swift examples/02-swift/01-struct-vs-class-good.swift
import Foundation

struct TransferDraft {
    var amount: Decimal
    var toAccount: String
}

let original = TransferDraft(amount: 100, toAccount: "000123456")
var edited = original              // a COPY
edited.amount = 5_000

print("original amount:", original.amount)   // 100 ✅ untouched
print("edited amount:  ", edited.amount)     // 5000
```

**Output**

```text
original amount: 100
edited amount:   5000
```
<!-- /example -->

---

## 2.2 Optionals

**Why it matters:** `!` means "I promise this is never nil". When the API breaks that promise, the app crashes. A crash in a banking app means a 1-star review and a support call.

### ❌ Bad

<!-- example: examples/02-swift/02-optionals-bad.swift -->
```swift
// ❌ BAD: force unwrap (!) → the app crashes when the value is missing
// Run: swift examples/02-swift/02-optionals-bad.swift

struct User {
    let nickname: String?
}

let user = User(nickname: nil)     // the API didn't send a nickname
print("Opening home screen…")
print("Hello, \(user.nickname!)")  // 💥 crash
```

**Output**

```text
Opening home screen…
02-optionals-bad.swift:11: Fatal error: Unexpectedly found nil while unwrapping an Optional value
💥 (the app crashes here; stack trace omitted)
```
<!-- /example -->

### ✅ Good

<!-- example: examples/02-swift/02-optionals-good.swift -->
```swift
// ✅ GOOD: unwrap safely with ??, guard let, if let and optional chaining
// Run: swift examples/02-swift/02-optionals-good.swift

struct User {
    let nickname: String?
}

// 1. ?? gives a default value
func greeting(for user: User) -> String {
    "Hello, \(user.nickname ?? "Guest")"
}

// 2. guard let exits early when the value is missing
func authorizationHeader(token: String?) -> String? {
    guard let token, !token.isEmpty else { return nil }
    return "Bearer \(token)"
}

print(greeting(for: User(nickname: nil)))                      // Hello, Guest
print(greeting(for: User(nickname: "Dara")))                   // Hello, Dara
print(authorizationHeader(token: nil) ?? "no token → show login")
print(authorizationHeader(token: "abc123") ?? "no token → show login")

// 3. if let runs code only when the value exists
let referralCode: String? = "SAVE10"
if let referralCode {
    print("Referral code applied:", referralCode)
}

// 4. Optional chaining: nil flows through instead of crashing
let nicknameLength = User(nickname: nil).nickname?.count
print("nickname length:", nicknameLength.map(String.init) ?? "nil")
```

**Output**

```text
Hello, Guest
Hello, Dara
no token → show login
Bearer abc123
Referral code applied: SAVE10
nickname length: nil
```
<!-- /example -->

**Rule of thumb:** `!` is only acceptable for values that are constant and known to be valid, e.g. a URL literal. Even then, `guard let` with a clear `fatalError("…")` message is better.

---

## 2.3 Screen state with an enum

**Why it matters:** separate `isLoading` / `error` / `data` flags can all be "on" at once, and the screen can't decide what to show. An enum with associated values makes impossible states impossible. It's the Swift version of React Query's `status`.

### ❌ Bad

<!-- example: examples/02-swift/03-view-state-bad.swift -->
```swift
// ❌ BAD: several flags that can contradict each other
// Run: swift examples/02-swift/03-view-state-bad.swift

struct AccountsScreenState {
    var isLoading = false
    var errorMessage: String?
    var accounts: [String] = []
}

var state = AccountsScreenState()
state.isLoading = true
state.accounts = ["Savings USD"]       // old data from the last load
state.errorMessage = "Network error"   // the refresh failed… and we forgot isLoading = false

// Spinner, error, or list? All three say "show me".
print("isLoading:", state.isLoading)
print("errorMessage:", state.errorMessage ?? "-")
print("accounts:", state.accounts)
print("→ the screen shows a spinner AND an error AND a list 🤯")
```

**Output**

```text
isLoading: true
errorMessage: Network error
accounts: ["Savings USD"]
→ the screen shows a spinner AND an error AND a list 🤯
```
<!-- /example -->

### ✅ Good

<!-- example: examples/02-swift/03-view-state-good.swift -->
```swift
// ✅ GOOD: one enum → exactly one state at a time, and the compiler forces you to handle every case
// Run: swift examples/02-swift/03-view-state-good.swift

enum ViewState<Value> {
    case loading
    case loaded(Value)
    case empty
    case failed(message: String)
}

func render(_ state: ViewState<[String]>) -> String {
    switch state {
    case .loading:              return "⏳ spinner"
    case .loaded(let accounts): return "📋 list: \(accounts.joined(separator: ", "))"
    case .empty:                return "🫙 \"No accounts yet\""
    case .failed(let message):  return "⚠️ \(message) [Try again]"
    }
}

let states: [ViewState<[String]>] = [
    .loading,
    .loaded(["Savings USD", "Current KHR"]),
    .empty,
    .failed(message: "Network error"),
]

for state in states {
    print(render(state))
}
```

**Output**

```text
⏳ spinner
📋 list: Savings USD, Current KHR
🫙 "No accounts yet"
⚠️ Network error [Try again]
```
<!-- /example -->

---

## 2.4 Money: Decimal, never Double

**Why it matters:**
- `Double` is binary floating point, so `0.1` can't be stored exactly.
- In a bank, that means wrong balances and false "insufficient funds" errors.
- Use `Decimal`, and ask the backend to send amounts as **strings** (or as integer minor units).

### ❌ Bad

<!-- example: examples/02-swift/04-money-bad.swift -->
```swift
// ❌ BAD: Double for money → binary floating-point rounding errors
// Run: swift examples/02-swift/04-money-bad.swift

let fee = 0.1
let tax = 0.2
print("0.1 + 0.2 =", fee + tax)                 // 0.30000000000000004
print("equals 0.3?", fee + tax == 0.3)          // false 😱

var balance = 0.0
for _ in 0..<10 { balance += 0.1 }              // ten deposits of $0.10
print("balance after 10 × $0.10 =", balance)
print("can pay $1.00?", balance >= 1.0)         // false → "insufficient funds" bug
```

**Output**

```text
0.1 + 0.2 = 0.30000000000000004
equals 0.3? false
balance after 10 × $0.10 = 0.9999999999999999
can pay $1.00? false
```
<!-- /example -->

### ✅ Good

<!-- example: examples/02-swift/04-money-good.swift -->
```swift
// ✅ GOOD: Decimal for money, created from strings (APIs should send amounts as strings)
// Run: swift examples/02-swift/04-money-good.swift
import Foundation

func money(_ text: String) -> Decimal {
    guard let value = Decimal(string: text) else { preconditionFailure("Invalid amount: \(text)") }
    return value
}

let fee = money("0.1")
let tax = money("0.2")
print("0.1 + 0.2 =", fee + tax)                 // 0.3
print("equals 0.3?", fee + tax == money("0.3")) // true ✅

var balance = Decimal.zero
for _ in 0..<10 { balance += money("0.10") }
print("balance after 10 × $0.10 =", balance)    // 1
print("can pay $1.00?", balance >= 1)           // true ✅
```

**Output**

```text
0.1 + 0.2 = 0.3
equals 0.3? true
balance after 10 × $0.10 = 1
can pay $1.00? true
```
<!-- /example -->

---

## 2.5 Retain cycles and `[weak self]`

**Why it matters:**
- Swift has **no garbage collector**. ARC frees an object when nothing holds it strongly.
- If A holds B and B holds A, neither is ever freed. Screens with balances stay in memory, and that memory adds up.
- The usual cause is a stored closure that captures `self`. `@escaping` closures (stored and called later) are where this happens.

| Keyword | Meaning | Use for |
|---|---|---|
| strong (default) | keeps the object alive | owner → owned |
| `weak` | doesn't keep it alive; becomes `nil` (always optional) | delegates, closures stored by objects you own |
| `unowned` | doesn't keep it alive; **crashes** if used after free | rarely worth the risk |

### ❌ Bad

<!-- example: examples/02-swift/05-retain-cycle-bad.swift -->
```swift
// ❌ BAD: a closure captures self strongly → retain cycle → the screen is never freed (memory leak)
// Run: swift examples/02-swift/05-retain-cycle-bad.swift

final class TransferViewModel {
    var onSuccess: (() -> Void)?
}

final class TransferScreen {
    let viewModel = TransferViewModel()
    let title = "Transfer"

    init() {
        // screen → viewModel → closure → screen: a cycle
        viewModel.onSuccess = {
            print("Showing receipt on \(self.title)")
        }
        print("TransferScreen created")
    }

    deinit { print("TransferScreen freed ✅") }
}

var screen: TransferScreen? = TransferScreen()
screen = nil                                   // the user leaves the screen
print("Screen closed. Did you see \"freed\"? No → memory leak 💧")
```

**Output**

```text
TransferScreen created
Screen closed. Did you see "freed"? No → memory leak 💧
```
<!-- /example -->

### ✅ Good

<!-- example: examples/02-swift/05-retain-cycle-good.swift -->
```swift
// ✅ GOOD: [weak self] breaks the cycle → the screen is freed when the user leaves
// Run: swift examples/02-swift/05-retain-cycle-good.swift

final class TransferViewModel {
    var onSuccess: (() -> Void)?
}

final class TransferScreen {
    let viewModel = TransferViewModel()
    let title = "Transfer"

    init() {
        viewModel.onSuccess = { [weak self] in
            guard let self else { return }      // the screen is already gone → do nothing
            print("Showing receipt on \(self.title)")
        }
        print("TransferScreen created")
    }

    deinit { print("TransferScreen freed ✅") }
}

var screen: TransferScreen? = TransferScreen()
screen?.viewModel.onSuccess?()                 // still works while the screen is alive
screen = nil                                   // the user leaves the screen
print("Screen closed.")
```

**Output**

```text
TransferScreen created
Showing receipt on Transfer
TransferScreen freed ✅
Screen closed.
```
<!-- /example -->

**Tip:** add `deinit { print("… freed") }` to every screen while learning. If it never prints after you go back, you have a leak. [11 · Devtools](11-devtools.md#memory-graph-find-retain-cycles) shows how to find it with the Memory Graph.

---

## 2.6 Error handling

**Why it matters:** `try?` turns every failure into `nil`, so you lose *why* it failed. Then you can't show "Not enough money" vs "Daily limit reached", and support can't help the customer.

### ❌ Bad

<!-- example: examples/02-swift/06-errors-bad.swift -->
```swift
// ❌ BAD: try? swallows the error → the user sees "nothing happened" and support can't help
// Run: swift examples/02-swift/06-errors-bad.swift
import Foundation

enum TransferError: Error {
    case insufficientFunds
    case dailyLimitReached
}

func sendTransfer(amount: Decimal, balance: Decimal) throws -> String {
    guard amount <= balance else { throw TransferError.insufficientFunds }
    return "RCPT-001"
}

let receipt = try? sendTransfer(amount: 500, balance: 120)
print("receipt:", receipt ?? "nil")            // nil… but WHY? The reason is lost.
```

**Output**

```text
receipt: nil
```
<!-- /example -->

### ✅ Good

<!-- example: examples/02-swift/06-errors-good.swift -->
```swift
// ✅ GOOD: specific errors, handled with do/catch, turned into a message the user understands
// Run: swift examples/02-swift/06-errors-good.swift
import Foundation

enum TransferError: Error, CustomStringConvertible {
    case insufficientFunds(available: Decimal)
    case dailyLimitReached

    var description: String {
        switch self {
        case .insufficientFunds(let available): return "Not enough money. Available: $\(available)"
        case .dailyLimitReached:                return "Daily limit reached. Try again tomorrow."
        }
    }
}

// throws(TransferError) = typed throws (Swift 6): callers know exactly which errors can happen
func sendTransfer(amount: Decimal, balance: Decimal) throws(TransferError) -> String {
    guard amount <= balance else { throw .insufficientFunds(available: balance) }
    return "RCPT-001"
}

for amount: Decimal in [50, 500] {
    do {
        let receipt = try sendTransfer(amount: amount, balance: 120)
        print("✅ sent $\(amount), receipt \(receipt)")
    } catch {
        print("⚠️ $\(amount): \(error)")       // `error` is a TransferError here
    }
}
```

**Output**

```text
✅ sent $50, receipt RCPT-001
⚠️ $500: Not enough money. Available: $120
```
<!-- /example -->

---

## 2.7 Dependency injection

**Why it matters:**
- If a ViewModel creates its own dependencies (`APIService.shared`), you can't test it, preview it, or run the app without the real server.
- Depend on a **protocol** (like a TypeScript `interface`) and pass the implementation in `init`.

### ❌ Bad

<!-- example: examples/02-swift/07-dependency-injection-bad.swift -->
```swift
// ❌ BAD: the ViewModel reaches for a singleton → you can't test it without the real server
// Run: swift examples/02-swift/07-dependency-injection-bad.swift

final class APIService: Sendable {
    static let shared = APIService()

    func fetchBalance() async throws -> String {
        print("  🌐 calling https://api.mybank.com/v1/balance … (needs internet, a real account, a real server)")
        return "$1,250.50"
    }
}

@MainActor
final class HomeViewModel {
    private(set) var balanceText = "–"

    func load() async {
        do {
            balanceText = try await APIService.shared.fetchBalance()   // hard-wired dependency
        } catch {
            balanceText = "Unavailable"
        }
    }
}

let viewModel = HomeViewModel()
await viewModel.load()
print("balance shown:", viewModel.balanceText)
print("How do you test the 'Unavailable' case? You can't, without breaking the real server.")
```

**Output**

```text
  🌐 calling https://api.mybank.com/v1/balance … (needs internet, a real account, a real server)
balance shown: $1,250.50
How do you test the 'Unavailable' case? You can't, without breaking the real server.
```
<!-- /example -->

### ✅ Good

<!-- example: examples/02-swift/07-dependency-injection-good.swift -->
```swift
// ✅ GOOD: depend on a protocol and inject it → swap in a mock for tests, previews and the Dev scheme
// Run: swift examples/02-swift/07-dependency-injection-good.swift

protocol BalanceProviding: Sendable {
    func fetchBalance() async throws -> String
}

struct LiveBalanceAPI: BalanceProviding {
    func fetchBalance() async throws -> String {
        // real URLSession call goes here (see examples/04-networking)
        "$1,250.50"
    }
}

struct MockBalanceAPI: BalanceProviding {
    struct Offline: Error {}
    var result: Result<String, Offline>
    func fetchBalance() async throws -> String { try result.get() }
}

@MainActor
final class HomeViewModel {
    private let api: any BalanceProviding
    private(set) var balanceText = "–"

    init(api: any BalanceProviding) { self.api = api }      // injected

    func load() async {
        do {
            balanceText = try await api.fetchBalance()
        } catch {
            balanceText = "Unavailable"
        }
    }
}

// "Tests": no network needed, every case is easy to reproduce
let happy = HomeViewModel(api: MockBalanceAPI(result: .success("$99.00")))
await happy.load()
print(happy.balanceText == "$99.00" ? "✅ shows balance" : "❌ failed")

let offline = HomeViewModel(api: MockBalanceAPI(result: .failure(.init())))
await offline.load()
print(offline.balanceText == "Unavailable" ? "✅ shows 'Unavailable' when offline" : "❌ failed")

// In the real app
let live = HomeViewModel(api: LiveBalanceAPI())
await live.load()
print("live app shows:", live.balanceText)
```

**Output**

```text
✅ shows balance
✅ shows 'Unavailable' when offline
live app shows: $1,250.50
```
<!-- /example -->

---

## 2.8 JSON with Codable

**Why it matters:** hand-parsing `[String: Any]` hides typos (silently `nil`) and type mismatches (crash with `as!`). `Codable` checks everything and tells you exactly which key or type is wrong.

### ❌ Bad

<!-- example: examples/02-swift/08-codable-bad.swift -->
```swift
// ❌ BAD: parsing JSON by hand with [String: Any] and force casts
// Run: swift examples/02-swift/08-codable-bad.swift
import Foundation

let json = #"{"id":"A1","acc_no":"000123456","balance":"1250.50","currency":"USD"}"#

let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
let accountNumber = object["account_number"] as? String   // typo in the key → silently nil
print("account number:", accountNumber ?? "nil 🤷")
let balance = object["balance"] as! Double                // 💥 it's a String in the JSON
print("balance:", balance)
```

**Output**

```text
account number: nil 🤷
Could not cast value of type 'Swift.String' to 'Swift.Double'.
💥 (the app crashes here; stack trace omitted)
```
<!-- /example -->

### ✅ Good

<!-- example: examples/02-swift/08-codable-good.swift -->
```swift
// ✅ GOOD: Codable + CodingKeys → type-safe, and bad data gives a clear error instead of a crash
// Run: swift examples/02-swift/08-codable-good.swift
import Foundation

struct AccountDTO: Decodable {
    let id: String
    let accountNumber: String
    let balance: String          // money as a string → no floating-point errors
    let currency: String

    enum CodingKeys: String, CodingKey {
        case id, balance, currency
        case accountNumber = "acc_no"   // JSON key differs from the Swift name
    }
}

let good = #"{"id":"A1","acc_no":"000123456","balance":"1250.50","currency":"USD"}"#
let broken = #"{"id":"A2","balance":"10.00","currency":"USD"}"#

for json in [good, broken] {
    do {
        let account = try JSONDecoder().decode(AccountDTO.self, from: Data(json.utf8))
        print("✅", account.accountNumber, account.balance, account.currency)
    } catch DecodingError.keyNotFound(let key, _) {
        print("❌ the API forgot the key:", key.stringValue)   // you know exactly what's wrong
    } catch {
        print("❌ decoding failed:", error)
    }
}
```

**Output**

```text
✅ 000123456 1250.50 USD
❌ the API forgot the key: acc_no
```
<!-- /example -->

> **Gotcha:** with `decoder.keyDecodingStrategy = .convertFromSnakeCase`, JSON keys are converted *before* matching. `acc_no` becomes `accNo`, so a `CodingKey` must be `"accNo"`, not `"acc_no"`. Use one approach per decoder: either `.convertFromSnakeCase` or explicit `CodingKeys`.

---

## Access control (reference)

| Level | Who can see it |
|---|---|
| `open` | everyone; subclasses in other modules can override |
| `public` | everyone, no overriding from other modules |
| `package` | modules in the same Swift package |
| `internal` (default) | the same module |
| `fileprivate` | the same file |
| `private` | the same type/scope (like JS `#private`) |

Swift has **no `protected`**: a subclass sees exactly what everyone else sees.

**Practice**

- [ ] Change `02-optionals-bad.swift` so it doesn't crash, without looking at the good version.
- [ ] Add a `.dailyLimitReached` case to `06-errors-good.swift` (limit $1,000) and test it.
- [ ] In `07-dependency-injection-good.swift`, add a mock that waits 2 s and check that the ViewModel still works.
- [ ] Decode an array of accounts where one item is missing `currency`. What happens? How would you skip only that item?

---

## Alternatives and trade-offs

**JSON**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| `Codable` (built-in) | type-safe, no dependency, clear errors | boilerplate for odd JSON; one bad item fails the whole array unless you handle it | default choice |
| Macro helpers (e.g. MetaCodable) | less `CodingKeys` boilerplate | adds a dependency and macro build time | many large, messy models |
| `JSONSerialization` / SwiftyJSON | flexible for unknown shapes | no type safety, typos become `nil`, crashes with `as!` | truly dynamic payloads only (e.g. analytics) |

**Money**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| `Decimal` | exact, easy formatting with `FormatStyle` | slower than integers; build it from strings, not `Double` literals | default for app code |
| Integer minor units (`Int64` cents) | exact, fast, easy to compare | need each currency's exponent (KHR vs USD); convert for display | the API sends minor units, or you do heavy math |
| `Double` | – | rounding errors | never for money |

**Dependency injection**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| Manual `init` injection (this guide) | zero magic, compile-time safe, easy to read | wiring code grows in big apps | default; small to medium apps |
| Factory | lightweight containers, compile-time-checked keys, easy test overrides | another dependency and pattern to learn | medium to large apps that want a container |
| Swinject | flexible runtime container, long history | a missing registration crashes at **runtime** | existing codebases already using it |
| swift-dependencies (Point-Free) | `@Dependency` with excellent test overrides | ties you to Point-Free conventions | you also use TCA, or like its testing style |
| Needle (Uber) | compile-time-generated graph for huge apps | code generation, setup cost | very large modular apps |

---

[← Index](../README.md) · [← Setup](01-setup.md) · [Next: Concurrency →](03-concurrency.md)
