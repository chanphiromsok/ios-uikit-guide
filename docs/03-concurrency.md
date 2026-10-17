# 03 · Concurrency: GCD and async/await

[← Index](../README.md) · [← Swift fundamentals](02-swift-fundamentals.md) · [Next: Networking and data →](04-networking-and-data.md)

Learn **both styles**:
- **GCD (`DispatchQueue`) + completion handlers** was the iOS standard for about ten years. Most existing banking codebases are full of it.
- **`async/await` + actors** has been Apple's standard since 2021. New code and job descriptions expect it.

| Year | Style | Status |
|---|---|---|
| ~2010–2019 | GCD + completion handlers, `OperationQueue` | Legacy, but everywhere |
| 2019 (iOS 13) | Combine | Still used for UI bindings (`@Published`) |
| 2021 (Swift 5.5) | **`async/await`, actors** | **Current standard** |
| 2024 (Swift 6) | Data races become compile errors | Current |
| 2025 (Xcode 26) | New app targets are `@MainActor` by default | Current |

> The language features work back to iOS 13, but `URLSession.data(for:)` needs iOS 15. Apps that still support iOS 13 or 14 often keep a completion-based network layer.

| Task | GCD / completion handler | async/await |
|---|---|---|
| Background work | `DispatchQueue.global().async { }` | `async` functions / `Task { }` |
| Back to the main thread | `DispatchQueue.main.async { }` | `@MainActor` |
| Return a result | `completion(.success(x))` | `return x` |
| Errors | `Result<T, Error>` + `switch` | `throw` / `do-catch` |
| Run 2 requests in parallel | `DispatchGroup` | `async let` |
| Protect shared state | private **serial** `DispatchQueue` | `actor` |
| Delay | `asyncAfter(deadline: .now() + 1)` | `try await Task.sleep(for: .seconds(1))` |
| Cancel | keep the task, call `cancel()` | `task.cancel()`, checked automatically |
| JS equivalent | callbacks | Promises + `async/await` |

| Topic | Bad | Good |
|---|---|---|
| [3.1 Completion handlers](#31-completion-handlers-gcd) | missing / background completion | `Result`, once, on main |
| [3.2 async/await and bridging](#32-asyncawait-and-bridging-old-apis) | continuation resumed twice | `withCheckedThrowingContinuation` |
| [3.3 Parallel requests](#33-parallel-requests) | sequential `await`s | `async let` / `DispatchGroup` |
| [3.4 Shared state](#34-shared-mutable-state) | data race | `actor` / serial queue |
| [3.5 Main thread](#35-ui-updates-on-the-main-thread) | UI from background | `@MainActor` |

---

## 3.1 Completion handlers (GCD)

**Why it matters:** the compiler can't check that a completion is called exactly once, or on the right thread. Forgetting it on one path means a spinner that never stops.

### ❌ Bad

<!-- example: examples/03-concurrency/01-completion-handler-bad.swift -->
```swift
// ❌ BAD: classic GCD mistakes
//   1. completion is NOT called on the error path → the spinner spins forever
//   2. completion is called on a background thread → UI updated from the wrong thread
// Run: swift examples/03-concurrency/01-completion-handler-bad.swift
import Foundation

func fetchBalance(failing: Bool, completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().async {                    // pretend this is the network
        if failing {
            print("  [network] request failed… and nobody is told 🙈")
            return                                    // mistake 1: no completion
        }
        completion("$1,250.50")                       // mistake 2: still on a background thread
    }
}

print("Request 1 (success):")
fetchBalance(failing: false) { balance in
    print("  completion: \(balance) — on main thread? \(Thread.isMainThread)")
}
Thread.sleep(forTimeInterval: 0.3)

print("Request 2 (failure):")
fetchBalance(failing: true) { _ in
    print("  completion called")                      // never printed
}

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    print("1 second later: request 2 never called back → the spinner spins forever")
    exit(0)
}
dispatchMain()                                        // keep this script alive for GCD
```

**Output**

```text
Request 1 (success):
  completion: $1,250.50 — on main thread? false
Request 2 (failure):
  [network] request failed… and nobody is told 🙈
1 second later: request 2 never called back → the spinner spins forever
```
<!-- /example -->

### ✅ Good (GCD style)

<!-- example: examples/03-concurrency/01-completion-handler-good.swift -->
```swift
// ✅ GOOD (GCD style): Result type, completion called EXACTLY once on every path, always on the main thread
// Run: swift examples/03-concurrency/01-completion-handler-good.swift
import Foundation

enum BalanceError: Error { case offline }

func fetchBalance(failing: Bool, delay: Double,
                  completion: @escaping @Sendable (Result<String, BalanceError>) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {     // pretend this is the network
        let result: Result<String, BalanceError> = failing ? .failure(.offline) : .success("$1,250.50")
        DispatchQueue.main.async { completion(result) }               // one exit point, main thread
    }
}

let group = DispatchGroup()

for (failing, delay) in [(false, 0.1), (true, 0.2)] {
    group.enter()
    fetchBalance(failing: failing, delay: delay) { result in
        dispatchPrecondition(condition: .onQueue(.main))   // stops in debug if we're NOT on the main queue
        switch result {
        case .success(let balance): print("✅ show \(balance) (on the main queue)")
        case .failure(let error):   print("⚠️ show error '\(error)' (on the main queue)")
        }
        group.leave()
    }
}

group.notify(queue: .main) {
    print("Both requests finished → hide the spinner")
    exit(0)
}
dispatchMain()                                        // keep this script alive for GCD
```

**Output**

```text
✅ show $1,250.50 (on the main queue)
⚠️ show error 'offline' (on the main queue)
Both requests finished → hide the spinner
```
<!-- /example -->

---

## 3.2 async/await, and bridging old APIs

**Why it matters:** you'll constantly need to call old completion-based code from new async code. Wrap it **once** with a continuation, and the rest of the app reads top to bottom.

### ✅ Good

<!-- example: examples/03-concurrency/02-async-await-good.swift -->
```swift
// ✅ GOOD (modern): wrap the old GCD API once, then write top-to-bottom async/await code
// Run: swift examples/03-concurrency/02-async-await-good.swift
import Foundation

enum BalanceError: Error { case offline }

// The old completion-handler API you inherited (same as 01-completion-handler-good.swift)
func fetchBalanceLegacy(failing: Bool,
                        completion: @escaping @Sendable (Result<String, BalanceError>) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
        let result: Result<String, BalanceError> = failing ? .failure(.offline) : .success("$1,250.50")
        DispatchQueue.main.async { completion(result) }
    }
}

// Bridge: completion handler → async/await
func fetchBalance(failing: Bool) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        fetchBalanceLegacy(failing: failing) { result in
            continuation.resume(with: result)         // resume EXACTLY once
        }
    }
}

// New code reads like normal synchronous code: no nesting, no manual thread hops.
// @MainActor = the compiler guarantees this runs on the main thread, so UI updates here are safe.
@MainActor
func loadHomeScreen() async {
    do {
        let balance = try await fetchBalance(failing: false)
        print("✅ show \(balance)")
        _ = try await fetchBalance(failing: true)
    } catch {
        print("⚠️ show error '\(error)'")
    }
}

await loadHomeScreen()
```

**Output**

```text
✅ show $1,250.50
⚠️ show error 'offline'
```
<!-- /example -->

### ❌ Bad: resuming a continuation twice

A continuation must be resumed **exactly once**:
- **Twice** → crash.
- **Never** → the caller waits forever, and Swift logs `SWIFT TASK CONTINUATION MISUSE: … leaked its continuation`.

<!-- example: examples/03-concurrency/02-continuation-bad.swift -->
```swift
// ❌ BAD: resuming a continuation twice → crash (forgetting to resume = the caller waits forever)
// Run: swift examples/03-concurrency/02-continuation-bad.swift
import Foundation

func fetchBalanceLegacy(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { completion("$1,250.50") }
}

func fetchBalance() async -> String {
    await withCheckedContinuation { continuation in
        fetchBalanceLegacy { balance in
            continuation.resume(returning: balance)   // 2nd resume → 💥
        }
        continuation.resume(returning: "$0.00")       // "default value" added by mistake → 1st resume
    }
}

let balance = await fetchBalance()
print("balance:", balance)
try await Task.sleep(for: .seconds(1))                // wait for the legacy callback to fire
```

**Output**

```text
balance: $0.00
_Concurrency/CheckedContinuation.swift:169: Fatal error: SWIFT TASK CONTINUATION MISUSE: fetchBalance() tried to resume its continuation more than once, returning $1,250.50!
💥 (the app crashes here; stack trace omitted)
```
<!-- /example -->

---

## 3.3 Parallel requests

**Why it matters:** awaiting independent requests one after another adds their times together. The home screen needs accounts *and* profile, so start both at once.

### ❌ Bad

<!-- example: examples/03-concurrency/03-parallel-bad.swift -->
```swift
// ❌ BAD: independent requests awaited one after another → the screen waits twice as long
// Run: swift examples/03-concurrency/03-parallel-bad.swift
import Foundation

func fetchAccounts() async throws -> [String] {
    try await Task.sleep(for: .seconds(1))            // pretend the network takes 1 s
    return ["Savings USD", "Current KHR"]
}

func fetchProfile() async throws -> String {
    try await Task.sleep(for: .seconds(1))
    return "Sok Dara"
}

let start = ContinuousClock.now
let accounts = try await fetchAccounts()              // waits 1 s…
let profile = try await fetchProfile()                // …THEN waits another 1 s
print(profile, accounts)
let elapsed = ContinuousClock.now - start
print("took \(elapsed.components.seconds) s")
```

**Output**

```text
Sok Dara ["Savings USD", "Current KHR"]
took 2 s
```
<!-- /example -->

### ✅ Good (async/await)

<!-- example: examples/03-concurrency/03-parallel-good.swift -->
```swift
// ✅ GOOD: async let runs independent requests at the same time (like Promise.all)
// Run: swift examples/03-concurrency/03-parallel-good.swift
import Foundation

func fetchAccounts() async throws -> [String] {
    try await Task.sleep(for: .seconds(1))
    return ["Savings USD", "Current KHR"]
}

func fetchProfile() async throws -> String {
    try await Task.sleep(for: .seconds(1))
    return "Sok Dara"
}

let start = ContinuousClock.now
async let accounts = fetchAccounts()                  // starts now
async let profile = fetchProfile()                    // also starts now
let (a, p) = try await (accounts, profile)            // wait for both
print(p, a)
let elapsed = ContinuousClock.now - start
print("took \(elapsed.components.seconds) s")
```

**Output**

```text
Sok Dara ["Savings USD", "Current KHR"]
took 1 s
```
<!-- /example -->

### ✅ Good (GCD style, for older codebases)

<!-- example: examples/03-concurrency/03-parallel-gcd-good.swift -->
```swift
// ✅ GOOD (GCD style): DispatchGroup runs requests in parallel; you will see this in older codebases
// Run: swift examples/03-concurrency/03-parallel-gcd-good.swift
import Foundation

func fetchAccounts(completion: @escaping @Sendable ([String]) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        let accounts = ["Savings USD", "Current KHR"]
        DispatchQueue.main.async { completion(accounts) }
    }
}

func fetchProfile(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        DispatchQueue.main.async { completion("Sok Dara") }
    }
}

// Results arrive on the main queue, so only the main thread touches this box
final class Results: @unchecked Sendable {
    var accounts: [String] = []
    var profile = ""
}

let start = ContinuousClock.now
let results = Results()
let group = DispatchGroup()

group.enter()
fetchAccounts { accounts in
    results.accounts = accounts
    group.leave()
}

group.enter()
fetchProfile { profile in
    results.profile = profile
    group.leave()
}

group.notify(queue: .main) {
    print(results.profile, results.accounts)
    let elapsed = ContinuousClock.now - start
    print("took \(elapsed.components.seconds) s")
    exit(0)
}
dispatchMain()
```

**Output**

```text
Sok Dara ["Savings USD", "Current KHR"]
took 1 s
```
<!-- /example -->

---

## 3.4 Shared mutable state

**Why it matters:**
- When several threads change the same variable, updates get lost: a data race.
- In a bank, that means wrong counters, a corrupted cache, or crashes that happen only for some users.
- An `actor` lets one caller in at a time. The GCD-era equivalent is a private **serial** queue.

### ❌ Bad

<!-- example: examples/03-concurrency/04-shared-state-bad.swift -->
```swift
// ❌ BAD: many tasks change the same variable with no protection → lost updates (a data race)
// Run: swift examples/03-concurrency/04-shared-state-bad.swift

final class BalanceCounter {
    var value = 0
}

let counter = BalanceCounter()
await withTaskGroup(of: Void.self) { group in
    for _ in 0..<10_000 {
        group.addTask { counter.value += 1 }          // read → add → write, from many threads at once
    }
}
print("expected 10000, got \(counter.value)")
```

**Output** (numbers change on every run)

```text
expected 10000, got 9983
```

**With Swift 6 strict checking (`-swift-version 6`), it doesn't even compile:**

```text
04-shared-state-bad.swift:14: error: non-Sendable type 'BalanceCounter' of let 'counter' cannot exit main actor-isolated context
04-shared-state-bad.swift:14: error: main actor-isolated let 'counter' cannot be accessed from outside of the actor
```
<!-- /example -->

### ✅ Good

<!-- example: examples/03-concurrency/04-shared-state-good.swift -->
```swift
// ✅ GOOD: an actor lets only one caller touch its state at a time (and the old GCD way: a serial queue)
// Run: swift examples/03-concurrency/04-shared-state-good.swift
import Foundation

actor BalanceCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

let counter = BalanceCounter()
await withTaskGroup(of: Void.self) { group in
    for _ in 0..<10_000 {
        group.addTask { await counter.increment() }
    }
}
print("actor: expected 10000, got \(await counter.value)")

// Before actors (and in older codebases): protect state with a private SERIAL DispatchQueue
final class LegacyCounter: @unchecked Sendable {      // @unchecked = "trust me, I made it safe myself"
    private var value = 0
    private let queue = DispatchQueue(label: "com.mybank.counter")   // serial: one job at a time

    func increment() { queue.sync { value += 1 } }
    var current: Int { queue.sync { value } }
}

let legacy = LegacyCounter()
DispatchQueue.concurrentPerform(iterations: 10_000) { _ in legacy.increment() }
print("serial queue: expected 10000, got \(legacy.current)")
```

**Output**

```text
actor: expected 10000, got 10000
serial queue: expected 10000, got 10000
```
<!-- /example -->

---

## 3.5 UI updates on the main thread

**Why it matters:** UIKit isn't thread-safe. Touching a `UILabel` from a background thread causes random glitches and crashes. UIKit types are `@MainActor`, and Swift 6 turns the mistake into a compile error.

### ❌ Bad

<!-- example: examples/03-concurrency/05-main-thread-bad.swift -->
```swift
// ❌ BAD: updating the UI from a background thread
// UIKit types like UILabel are @MainActor. This fake Label behaves the same way, so it runs anywhere.
// Old Swift 5 code like this compiled (often with just a warning) and caused random UI glitches and crashes.
// Swift 6 refuses to build it.
// Run: swift examples/03-concurrency/05-main-thread-bad.swift
import Foundation

@MainActor
final class Label {
    var text = ""
}

@MainActor
func showBalance(on label: Label) {
    DispatchQueue.global().async {
        // pretend we just got the balance from the network…
        label.text = "$1,250.50"                      // ❌ UI touched off the main thread
    }
}
```

**Output**

```text
05-main-thread-bad.swift:18: error: main actor-isolated property 'text' can not be mutated from a Sendable closure
```
<!-- /example -->

### ✅ Good

<!-- example: examples/03-concurrency/05-main-thread-good.swift -->
```swift
// ✅ GOOD: do the slow work in the background, then update the UI on the main actor
// Run: swift examples/03-concurrency/05-main-thread-good.swift
import Foundation

@MainActor
final class Label {
    var text = "" { didSet { print("label.text = \(text)") } }
}

func fetchBalance() async throws -> String {
    try await Task.sleep(for: .milliseconds(200))     // network work happens off the main thread
    return "$1,250.50"
}

@MainActor
final class HomeViewController {                      // in UIKit, UIViewController is already @MainActor
    let balanceLabel = Label()

    func viewDidLoad() async {
        balanceLabel.text = "Loading…"
        do {
            let balance = try await fetchBalance()
            balanceLabel.text = balance               // ✅ back on the main actor automatically
        } catch {
            balanceLabel.text = "Unavailable"
        }
    }
}

await HomeViewController().viewDidLoad()

// GCD-style equivalent you'll see in older code:
// DispatchQueue.global().async {
//     let value = slowWork()
//     DispatchQueue.main.async { label.text = value }
// }
```

**Output**

```text
label.text = Loading…
label.text = $1,250.50
```
<!-- /example -->

**Practice**

- [ ] Rewrite `01-completion-handler-bad.swift` so every path calls `completion` exactly once, on the main queue.
- [ ] Add a third request (cards) to `03-parallel-good.swift`. The total should still be about 1 s.
- [ ] Run `04-shared-state-bad.swift` three times. Is the number the same each time? Why not?
- [ ] Wrap a completion-based `fetchProfile(completion:)` with `withCheckedThrowingContinuation`.

---

## Alternatives and trade-offs

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| **async/await + actors** | readable, compile-time race checks (Swift 6), built-in cancellation | learning curve (`Sendable`, isolation); `URLSession` async APIs need iOS 15 | **all new code** |
| GCD (`DispatchQueue`) | everywhere in older code, simple for "run this later" | no compile-time safety; easy to forget completions or the main queue | maintaining legacy code; tiny fire-and-forget work |
| `OperationQueue` | dependencies between operations, `maxConcurrentOperationCount`, cancellation | verbose subclassing | upload/download queues with limits (e.g. KYC document uploads) |
| Combine | operators (`debounce`, `combineLatest`), works well with `@Published` | Apple has added little to it lately; harder to debug | UI bindings, search debounce in existing Combine code |
| RxSwift + RxCocoa | very common in older Asian banking codebases; rich operators | big dependency, steep learning curve, overlaps async/await | joining a team that already uses it (learn to read it!) |
| AsyncSequence + swift-async-algorithms | `debounce`, `merge`, `combineLatest` for async code | extra package; still young | stream-like features in modern code |

---

[← Index](../README.md) · [← Swift fundamentals](02-swift-fundamentals.md) · [Next: Networking and data →](04-networking-and-data.md)
