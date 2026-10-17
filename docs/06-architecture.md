# 06 · Architecture and modularization

[← Index](../README.md) · [← UIKit](05-uikit.md) · [Next: Environments →](07-environments.md)

| Topic | Bad | Good |
|---|---|---|
| [6.1 "Code splitting" on iOS](#61-code-splitting-on-ios) | – | Swift Package modules |
| [6.2 MVVM + Coordinator](#62-mvvm--coordinator) | Massive View Controller | testable ViewModel |
| [6.3 BankKit: a real package](#63-bankkit-a-real-package-with-tests) | – | 🐧 `swift test` |

---

## 6.1 "Code splitting" on iOS

It's **not** like React:

- The whole compiled binary ships through the App Store.
- **Apple forbids downloading new executable code** (App Store Review Guideline 2.5.2). That's why React Native can push over-the-air JS updates and native Swift can't.

On iOS, code splitting means **modularization**: splitting the codebase into Swift Packages.

```
MyBankApp (thin shell: AppDelegate, SceneDelegate, Coordinators, DI wiring)
├── Features/
│   ├── LoginFeature       ← each a Swift Package (or a target in one package)
│   ├── AccountsFeature
│   ├── TransferFeature
│   └── KHQRFeature
└── Core/
    ├── Networking
    ├── Persistence
    ├── Security
    └── DesignSystem
```

- **Rule:** features depend on Core and **never on each other**. The app shell wires them together.
- **Boundaries are enforced by access control.** Only `public` code is visible outside a module, like a package's exports.
- **Benefits:** faster incremental builds, clear ownership, isolated tests, a demo app per feature.
- **Runtime laziness still exists.** A VC isn't created until you navigate to it. That's the closest thing to `React.lazy`, but it saves memory, not download size.
- **Prefer static linking.** Many dynamic frameworks slow down app launch.
- **Use Swift Package Manager.** CocoaPods is being wound down.

---

## 6.2 MVVM + Coordinator

```
Coordinator ── creates ──▶ ViewController ── owns ──▶ ViewModel ── uses ──▶ Repository ──▶ API / Cache
     ▲                           │                       │
     └─── "user tapped X" ───────┘    state changes  ◀───┘
```

| Layer | Knows about | Never knows about |
|---|---|---|
| ViewController | its ViewModel, UIKit | network, JSON, other screens |
| ViewModel | repositories, domain models | UIKit → unit-testable |
| Repository | API, cache, mapping | UI |
| Coordinator | which screen comes next | business rules |

### ❌ Bad: Massive View Controller

<!-- example: examples/06-architecture/01-massive-view-controller-bad.swift -->
```swift
// ❌ BAD: "Massive View Controller": networking, JSON parsing, formatting, business rules and navigation in one class
// Run: swift examples/06-architecture/01-massive-view-controller-bad.swift
import Foundation

@MainActor
final class AccountsViewController {                 // imagine this is a UIViewController
    var titleText = ""
    var rows: [String] = []

    func viewDidLoad() async {
        // 1. networking
        let json = await downloadJSON(from: "https://api.mybank.example/v1/accounts")
        // 2. parsing
        let objects = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [[String: Any]] ?? []
        // 3. formatting + business rules
        rows = objects.map { object in
            let balance = Double(object["balance"] as? String ?? "") ?? 0
            let warning = balance < 10 ? " ⚠️ low balance" : ""
            return "\(object["name"] as? String ?? "?"): $\(String(format: "%.2f", balance))\(warning)"
        }
        titleText = "\(rows.count) accounts"
        // 4. navigation
        if rows.isEmpty { print("→ push OpenAccountViewController") }
    }

    private func downloadJSON(from url: String) async -> String {
        print("  🌐 GET \(url)  (every test needs the real server)")
        return #"[{"name":"Savings","balance":"1250.5"},{"name":"Wallet","balance":"3.2"}]"#
    }
}

let viewController = AccountsViewController()
await viewController.viewDidLoad()
print(viewController.titleText)
viewController.rows.forEach { print("  \($0)") }
print("To test the 'low balance' rule you must run the whole screen and the network.")
```

**Output**

```text
  🌐 GET https://api.mybank.example/v1/accounts  (every test needs the real server)
2 accounts
  Savings: $1250.50
  Wallet: $3.20 ⚠️ low balance
To test the 'low balance' rule you must run the whole screen and the network.
```
<!-- /example -->

### ✅ Good: MVVM with a testable ViewModel

<!-- example: examples/06-architecture/01-mvvm-good.swift -->
```swift
// ✅ GOOD: MVVM: the ViewModel holds the logic and state, with no UIKit → it can be unit-tested in milliseconds
// Run: swift examples/06-architecture/01-mvvm-good.swift
import Foundation

struct Account: Sendable {
    let name: String
    let balance: Decimal
}

protocol AccountsRepository: Sendable {
    func accounts() async throws -> [Account]
}

struct AccountRowViewData: Equatable {
    let title: String
    let balanceText: String
    let showsLowBalanceWarning: Bool
}

@MainActor
final class AccountsViewModel {
    enum State: Equatable {
        case loading
        case loaded([AccountRowViewData])
        case empty
        case failed(String)
    }

    private(set) var state: State = .loading
    var onOpenAccount: (() -> Void)?                 // navigation is the Coordinator's job

    private let repository: any AccountsRepository
    private let locale: Locale

    init(repository: any AccountsRepository, locale: Locale = .current) {
        self.repository = repository
        self.locale = locale
    }

    func load() async {
        do {
            let accounts = try await repository.accounts()
            state = accounts.isEmpty ? .empty : .loaded(accounts.map(makeRow))
        } catch {
            state = .failed("Couldn't load accounts")
        }
    }

    func openAccountTapped() { onOpenAccount?() }

    private func makeRow(_ account: Account) -> AccountRowViewData {
        AccountRowViewData(
            title: account.name,
            balanceText: account.balance.formatted(.currency(code: "USD").locale(locale)),
            showsLowBalanceWarning: account.balance < 10
        )
    }
}

// The view controller only renders `state` and forwards taps.
// Below are real "unit tests" against the ViewModel: no UI, no network.

struct StubRepository: AccountsRepository {
    let result: Result<[Account], any Error>
    func accounts() async throws -> [Account] { try result.get() }
}

struct Offline: Error {}

func check(_ name: String, _ condition: Bool) { print(condition ? "✅" : "❌", name) }
func usd(_ text: String) -> Decimal { Decimal(string: text) ?? 0 }
let english = Locale(identifier: "en_US")

let lowBalance = AccountsViewModel(
    repository: StubRepository(result: .success([Account(name: "Wallet", balance: usd("3.20"))])), locale: english)
await lowBalance.load()
check("low balance shows a warning",
      lowBalance.state == .loaded([AccountRowViewData(title: "Wallet", balanceText: "$3.20", showsLowBalanceWarning: true)]))

let noAccounts = AccountsViewModel(repository: StubRepository(result: .success([])), locale: english)
await noAccounts.load()
check("no accounts → empty state", noAccounts.state == .empty)

let offline = AccountsViewModel(repository: StubRepository(result: .failure(Offline())), locale: english)
await offline.load()
check("offline → error state", offline.state == .failed("Couldn't load accounts"))

var openedAccountScreen = false
noAccounts.onOpenAccount = { openedAccountScreen = true }
noAccounts.openAccountTapped()
check("tap 'Open account' asks the coordinator to navigate", openedAccountScreen)
```

**Output**

```text
✅ low balance shows a warning
✅ no accounts → empty state
✅ offline → error state
✅ tap 'Open account' asks the coordinator to navigate
```
<!-- /example -->

How the ViewModel tells the view controller to update:
- **Combine:** `@Published var state` + `sink`.
- **Callback:** an `onChange` closure, as in [5.8](05-uikit.md#58-list--detail-pass-the-id-fetch-by-id).
- **Observation (iOS 26+):** `@Observable`, which UIKit tracks automatically in `updateProperties()` and `layoutSubviews()`.

---

## 6.3 BankKit: a real package with tests

[`examples/06-architecture/BankKit`](../examples/06-architecture/BankKit) is the start of your capstone's Core layer.

```
BankKit/
├── Package.swift
├── Sources/
│   ├── Networking/          APIClient (status checks, 401 → refresh → retry), TokenProvider (actor)
│   └── Banking/             Money, Currency, TransactionDTO → Transaction → TransactionRowViewData,
│                            TransactionRepository (actor: TTL + dedupe + invalidate)
└── Tests/
    ├── NetworkingTests/     5 concurrent 401s → 1 refresh, …
    └── BankingTests/        mapping, money formatting (USD/KHR), cache behaviour
```

```bash
cd examples/06-architecture/BankKit
swift test
```

Result of the test run used for this guide (Swift 6.4.1, Linux):

```text
✔ Suite "TokenProvider" passed after 0.051 seconds.
✔ Test run with 3 tests in 1 suite passed after 0.051 seconds.
✔ Suite "DTO → Domain → ViewData" passed after 0.002 seconds.
✔ Suite "TransactionRepository" passed after 0.133 seconds.
✔ Test run with 9 tests in 2 suites passed after 0.133 seconds.
```

The tests use **Swift Testing** (`@Test`, `#expect`), which is built into Swift 6 toolchains and Xcode 16+. To use the package in your app: Xcode → File → Add Package Dependencies… → Add Local…, then select the `BankKit` folder.

**Practice**

- [ ] Add an `AccountRepository` to `Banking` with its own tests.
- [ ] Add a `DesignSystem` target (colors, fonts, a `PrimaryButton`) to BankKit. Which module should depend on it?
- [ ] Write a test proving that `APIClient` maps a 500 response to `APIError.server(statusCode: 500)`. Hint: use the `FakeServer` from [04 · 4.1](04-networking-and-data.md#41-fetching-with-urlsession).

---

## Alternatives and trade-offs

**Architecture patterns**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| MVC (Apple's default) | simplest, least code | VCs grow huge ("Massive View Controller") | tiny apps, prototypes |
| **MVVM + Coordinator** (this guide) | testable ViewModels, clear navigation | binding boilerplate | default for UIKit banking apps |
| VIPER / Clean Swift (VIP) | strict layers, big-team friendly, testable | many files per screen; slow to change | large banks with many teams |
| TCA (The Composable Architecture) | unidirectional (Redux-like), excellent tests | learning curve, SwiftUI-first, big dependency | teams already using it, mostly SwiftUI |
| ReactorKit | unidirectional with RxSwift | requires RxSwift | RxSwift codebases |

**Modules and project files**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| **Swift Package Manager** local packages | built-in, Xcode support, fast tests | large graphs can slow Xcode indexing | default |
| Tuist | generates projects, caching, module graph rules, fewer merge conflicts | learn a tool + manifest language | many modules and teams |
| XcodeGen | YAML → `.xcodeproj`, no project merge conflicts | another config file; regenerate after changes | mid-size teams tired of pbxproj conflicts |
| Bazel (rules_apple) | huge monorepos, remote caching | steep setup and maintenance | very large companies |
| CocoaPods / Carthage | lots of legacy libraries | CocoaPods is being wound down; slower builds | only to maintain old projects |

---

[← Index](../README.md) · [← UIKit](05-uikit.md) · [Next: Environments →](07-environments.md)
