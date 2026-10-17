# 16 · Patterns from the Telegram iOS source code

[← Index](../README.md) · [← GCD deep dive](15-gcd.md)

[Telegram for iOS](https://github.com/TelegramMessenger/Telegram-iOS) is one of the largest, most performance-focused open-source iOS apps. It has its own UI framework (`Display`, built on AsyncDisplayKit) and its own reactive library (`SwiftSignalKit`). This page takes **the ideas** that are useful for a banking app and re-implements them in small, modern Swift 6 code you can run.

**How this page was made:**
1. A Haiku agent searched the Telegram source at commit [`f1dd7a2`](https://github.com/TelegramMessenger/Telegram-iOS/tree/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838) (7 Oct 2026).
2. Every finding used here was checked against the actual files; the links below point to the exact lines.
3. The 🐧 examples ran with Swift 6.4.1 in both Swift 5 and Swift 6 modes. The 🍎 files need Xcode and weren't compiled.

> ⚖️ **License:**
> - Telegram's code is published under copyleft licenses; its README asks developers to publish their own code too.
> - **Nothing here is copied from Telegram.** Every example is an independent implementation of the *idea*, with a link to the original so you can study it.
> - Don't paste Telegram's code into a closed-source app such as a bank's. Study it, then write your own.

| # | Pattern | Telegram original | Banking use |
|---|---|---|---|
| [16.1](#161-a-serial-queue-that-knows-where-it-is) | Serial queue that knows "am I on it?" | [`Queue`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/SSignalKit/SwiftSignalKit/Source/Queue.swift#L9) | caches, token storage without deadlocks |
| [16.2](#162-atomic-a-value-and-its-lock-together) | `Atomic<T>`: value + lock together | [`Atomic`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/SSignalKit/SwiftSignalKit/Source/Atomic.swift#L7) | counters, event buffers, flags |
| [16.3](#163-latest-only-cancel-the-previous-job) | Latest-only: new job cancels the old | [`MetaDisposable`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/SSignalKit/SwiftSignalKit/Source/Disposable.swift#L83) | search, list → detail, filters |
| [16.4](#164-a-bag-of-jobs-that-dies-with-the-screen) | A bag of jobs that dies with the screen | [`DisposableSet`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/SSignalKit/SwiftSignalKit/Source/Disposable.swift#L152) | stop downloads when the user leaves |
| [16.5](#165-a-timer-that-cant-leak-its-owner) | Timer that can't leak its owner | [`Timer`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/SSignalKit/SwiftSignalKit/Source/Timer.swift#L3) | OTP countdown, session timeout, polling |
| [16.6](#166-an-observable-value-done-right) | Observable value done right | [`ValuePromise`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/SSignalKit/SwiftSignalKit/Source/Promise.swift#L82), [`ValuePipe`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/SSignalKit/SwiftSignalKit/Source/ValuePipe.swift#L3) | live balance, settings changes |
| [16.7](#167-coalesce-many-updates-into-one-ui-update) | Coalesce many updates into one UI update | [`debounceOnMainThread`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/ChatListUI/Sources/ChatListSearchListPaneNode.swift#L6734) | sync responses, socket bursts |
| [16.8](#168-throttle-repeated-taps) | Throttle repeated taps | [`Throttler`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/TelegramCallsUI/Sources/Components/MediaStreamComponent.swift#L2047) | "Resend OTP", refresh, Pay |
| [16.9](#169-one-layout-function-immediate-or-animated) | One layout function, immediate or animated | [`ContainedViewLayoutTransition`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/Display/Source/ContainedViewLayoutTransition.swift#L129) | expanding cards, show/hide balance |
| [16.10](#1610-small-uikit-helpers) | Small UIKit helpers | [`HapticFeedback`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/Display/Source/HapticFeedback.swift#L128), [`UIColor(rgb:)`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/Display/Source/UIKitUtils.swift#L70), [`generateImage`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/Display/Source/GenerateImage.swift#L102), [first responder](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/Display/Source/KeyboardManager.swift#L15) | haptics, brand colors, avatars, keyboard |

---

## 16.1 A serial queue that knows where it is

**In Telegram:** `Queue` wraps a `DispatchQueue` and tags it with `setSpecific(key:value:)`.
- **`isCurrent()`** reads the tag back with `DispatchQueue.getSpecific(key:)` to answer "am I running on this queue right now?".
- **`sync` and `async` run the closure *immediately*** when you're already on the queue.

**Why it's clever:** it removes the classic deadlock from [15.2](15-gcd.md#152-sync-onto-your-own-queue-deadlock). A method on the queue can call another method that also uses the queue.

### ✅ Our version

<!-- example: examples/16-telegram-patterns/01-serial-queue-good.swift -->
```swift
// ✅ IDEA FROM TELEGRAM (SwiftSignalKit `Queue`): a serial queue that knows whether you're already on it.
// Nested sync calls run inline instead of deadlocking (compare examples/15-gcd/02-sync-deadlock-bad.swift).
// Written from scratch for this guide; not Telegram's code.
// Run: swift examples/16-telegram-patterns/01-serial-queue-good.swift
import Foundation

final class SerialQueue: @unchecked Sendable {
    private let queue: DispatchQueue
    private let key = DispatchSpecificKey<Bool>()        // a per-queue tag, readable from inside the queue

    init(label: String, qos: DispatchQoS = .default) {
        queue = DispatchQueue(label: label, qos: qos)
        queue.setSpecific(key: key, value: true)
    }

    /// true while running on this queue
    var isCurrent: Bool { DispatchQueue.getSpecific(key: key) == true }

    /// Runs now if we're already on this queue; otherwise hops onto it and waits.
    func sync<T>(_ work: () throws -> T) rethrows -> T {
        isCurrent ? try work() : try queue.sync(execute: work)
    }

    /// Runs now if already on this queue (keeps ordering with the surrounding code); otherwise dispatches.
    func asyncOrInline(_ work: @escaping @Sendable () -> Void) {
        if isCurrent { work() } else { queue.async(execute: work) }
    }
}

final class BalanceCache: @unchecked Sendable {
    private let queue = SerialQueue(label: "com.mybank.balance-cache")
    private var balances: [String: String] = [:]

    func balance(for account: String) -> String? {
        queue.sync { balances[account] }
    }

    func update(_ account: String, to value: String) {
        queue.sync {
            balances[account] = value
            print("saved \(account), reading it back… (on the queue? \(queue.isCurrent))")
            print("value:", balance(for: account) ?? "nil")   // nested sync → runs inline, no deadlock
        }
    }
}

let cache = BalanceCache()
cache.update("000123456", to: "$1,250.50")
print("from outside:", cache.balance(for: "000123456") ?? "nil")
```

**Output**

```text
saved 000123456, reading it back… (on the queue? true)
value: $1,250.50
from outside: $1,250.50
```
<!-- /example -->

**Trade-offs:**
- **Hidden layering mistakes.** Running inline hides them; the explicit fix in [15.2](15-gcd.md#152-sync-onto-your-own-queue-deadlock) is often clearer.
- **"async" that isn't async.** Telegram's method is named `async` but can run synchronously. We called ours `asyncOrInline` so the name tells the truth.
- **New code:** an `actor` gives you the same safety with compiler checks.

---

## 16.2 Atomic: a value and its lock together

**In Telegram:** `Atomic<T>` keeps a value next to a `pthread_mutex_t`. You can only reach the value through `with { }`, `modify { }` and `swap(_:)`, which all lock.

**Why it's clever:** you *can't* forget the lock. There's no way to read the value without it.

### ✅ Our version

<!-- example: examples/16-telegram-patterns/02-atomic-good.swift -->
```swift
// ✅ IDEA FROM TELEGRAM (SwiftSignalKit `Atomic<T>`): wrap a value and its lock together, so it can't be
// touched without the lock. Written from scratch: NSLock, `defer` unlock, `inout` modify.
// Run: swift examples/16-telegram-patterns/02-atomic-good.swift
import Foundation

final class Atomic<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    /// Read (or compute something from) the value while holding the lock.
    func with<Result>(_ body: (Value) throws -> Result) rethrows -> Result {
        lock.lock(); defer { lock.unlock() }
        return try body(value)
    }

    /// Change the value in place while holding the lock.
    @discardableResult
    func modify<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock(); defer { lock.unlock() }
        return try body(&value)
    }

    /// Replace the value and get the old one back in one step (handy for "take everything and reset").
    func swap(_ newValue: Value) -> Value {
        modify { current in
            let old = current
            current = newValue
            return old
        }
    }
}

// 1. A counter updated from many threads at once
let taps = Atomic(0)
DispatchQueue.concurrentPerform(iterations: 10_000) { _ in taps.modify { $0 += 1 } }
print("taps: expected 10000, got \(taps.with { $0 })")

// 2. Analytics events collected from many threads, then flushed as one batch
let pendingEvents = Atomic<[String]>([])
DispatchQueue.concurrentPerform(iterations: 250) { index in
    pendingEvents.modify { $0.append("screen_view_\(index)") }
}
let batch = pendingEvents.swap([])                  // take all events and empty the buffer atomically
print("uploading \(batch.count) events; left in buffer: \(pendingEvents.with(\.count))")

// ⚠️ The lock is not recursive: calling taps.with { _ in taps.with { … } } would deadlock.
```

**Output**

```text
taps: expected 10000, got 10000
uploading 250 events; left in buffer: 0
```
<!-- /example -->

**What we changed, and why:**
- **`NSLock` instead of `pthread_mutex_t`.** Swift doesn't promise a stable memory address for a `pthread_mutex_t` stored as a property. Apple recommends `OSAllocatedUnfairLock` (iOS 16+) or `Mutex` (iOS 18+); `NSLock` is safe everywhere.
- **`defer { unlock() }`.** The lock is released even if the closure throws.
- **`modify` takes `inout`.** Telegram's takes `(T) -> T`; `inout` avoids copying big values.
- **Same caveat as Telegram's:** the lock is **not recursive**, so never call `with` inside `with`.

---

## 16.3 Latest-only: cancel the previous job

**In Telegram:** `MetaDisposable` holds *one* subscription. `set(_:)` disposes the previous one before storing the new one. If the holder itself was already disposed, anything set later is disposed immediately.

**Why it matters:** search, filters and list → detail ([05 · 5.8](05-uikit.md#58-list--detail-pass-the-id-fetch-by-id)) all have the same bug: an old, slow request finishes last and overwrites the new result.

### ❌ Bad

<!-- example: examples/16-telegram-patterns/03-latest-only-bad.swift -->
```swift
// ❌ BAD: every keystroke starts a search and nothing cancels the old ones → a slow, old result
//         can arrive LAST and overwrite the newest one
// Run: swift examples/16-telegram-patterns/03-latest-only-bad.swift
import Foundation

func searchPayees(_ query: String) async throws -> [String] {
    try await Task.sleep(for: .milliseconds(query.count == 1 ? 300 : 100))   // short queries are slower
    return ["\(query) result A", "\(query) result B"]
}

@MainActor
final class PayeeSearchViewController {
    private(set) var shownQuery = ""

    func searchTextChanged(_ query: String) {
        Task {
            guard let results = try? await searchPayees(query) else { return }
            shownQuery = query                               // ❌ whoever finishes last wins
            print("rendered \(results.count) results for \"\(query)\"")
        }
    }
}

@MainActor
func demo() async throws {
    let screen = PayeeSearchViewController()
    screen.searchTextChanged("s")                            // slow
    try await Task.sleep(for: .milliseconds(50))
    screen.searchTextChanged("sok")                          // fast
    try await Task.sleep(for: .milliseconds(500))
    print("user typed \"sok\", screen shows results for \"\(screen.shownQuery)\" ❌")
}

try await demo()
```

**Output**

```text
rendered 2 results for "sok"
rendered 2 results for "s"
user typed "sok", screen shows results for "s" ❌
```
<!-- /example -->

### ✅ Our version: `LatestTask`

<!-- example: examples/16-telegram-patterns/03-latest-only-good.swift -->
```swift
// ✅ IDEA FROM TELEGRAM (`MetaDisposable`): a holder for "the current job". Setting a new one cancels
//    the previous, so only the latest request can update the screen. Written from scratch for Tasks.
// Run: swift examples/16-telegram-patterns/03-latest-only-good.swift
import Foundation

@MainActor
final class LatestTask {
    private var task: Task<Void, Never>?

    /// Cancels the previous job, then starts this one.
    func run(_ operation: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task { await operation() }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

func searchPayees(_ query: String) async throws -> [String] {
    try await Task.sleep(for: .milliseconds(query.count == 1 ? 300 : 100))   // throws CancellationError if cancelled
    return ["\(query) result A", "\(query) result B"]
}

@MainActor
final class PayeeSearchViewController {
    private let search = LatestTask()
    private(set) var shownQuery = ""

    func searchTextChanged(_ query: String) {
        search.run { [weak self] in
            do {
                let results = try await searchPayees(query)
                guard !Task.isCancelled else { return }      // a newer search started while we waited
                self?.shownQuery = query
                print("rendered \(results.count) results for \"\(query)\"")
            } catch {
                print("search for \"\(query)\" cancelled ✅")
            }
        }
    }
}

@MainActor
func demo() async throws {
    let screen = PayeeSearchViewController()
    screen.searchTextChanged("s")
    try await Task.sleep(for: .milliseconds(50))
    screen.searchTextChanged("sok")
    try await Task.sleep(for: .milliseconds(500))
    print("user typed \"sok\", screen shows results for \"\(screen.shownQuery)\" ✅")
}

try await demo()
```

**Output**

```text
search for "s" cancelled ✅
rendered 2 results for "sok"
user typed "sok", screen shows results for "sok" ✅
```
<!-- /example -->

Cancellation in Swift is **cooperative**. `Task.sleep` and `URLSession` notice it automatically; your own loops must check `Task.isCancelled`.

---

## 16.4 A bag of jobs that dies with the screen

**In Telegram:** `DisposableSet` (and `DisposableDict`) collect subscriptions and dispose all of them together. A subscription added **after** the set was disposed is disposed immediately. In debug builds, Telegram's [`StrictDisposable`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/SSignalKit/SwiftSignalKit/Source/Disposable.swift#L7) also **asserts** if a subscription was never disposed, which works as a built-in leak detector.

**Why it matters:**
- **`[weak self]` alone isn't enough.** It prevents the leak, but the downloads still run after the user leaves, wasting data and battery and putting load on the server.

### ❌ Bad

<!-- example: examples/16-telegram-patterns/04-task-bag-bad.swift -->
```swift
// ❌ BAD: the screen starts requests and never keeps a handle on them → after the user leaves,
//         every request still downloads (data, battery, server load) for a screen nobody sees
// Run: swift examples/16-telegram-patterns/04-task-bag-bad.swift
import Foundation

@MainActor
final class Stats {
    static let shared = Stats()
    var finishedAfterLeaving = 0
    var cancelled = 0
}

@MainActor
final class HomeViewController {
    func viewDidLoad() {
        for item in ["balance", "cards", "offers"] {
            Task { [weak self] in                              // weak self avoids a leak…
                do {
                    try await Task.sleep(for: .seconds(1))     // pretend download
                    Stats.shared.finishedAfterLeaving += 1     // …but the work still happens
                    self?.render(item)
                } catch {
                    Stats.shared.cancelled += 1
                }
            }
        }
    }

    func render(_ item: String) { print("render \(item)") }
    deinit { print("HomeViewController freed") }
}

@MainActor
func demo() async throws {
    var screen: HomeViewController? = HomeViewController()
    screen?.viewDidLoad()
    try await Task.sleep(for: .milliseconds(200))
    screen = nil                                               // the user goes back after 0.2 s
    print("user left the screen")
    try await Task.sleep(for: .seconds(1.5))
    print("downloads finished after leaving: \(Stats.shared.finishedAfterLeaving), cancelled: \(Stats.shared.cancelled) ❌")
}

try await demo()
```

**Output**

```text
HomeViewController freed
user left the screen
downloads finished after leaving: 3, cancelled: 0 ❌
```
<!-- /example -->

### ✅ Our version: `TaskBag`

<!-- example: examples/16-telegram-patterns/04-task-bag-good.swift -->
```swift
// ✅ IDEA FROM TELEGRAM (`DisposableSet`): the screen owns a bag of jobs and cancels them all when it goes
//    away. Jobs added after the bag was cancelled are cancelled immediately. Written from scratch.
// Run: swift examples/16-telegram-patterns/04-task-bag-good.swift
import Foundation

final class TaskBag: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [Task<Void, Never>] = []
    private var isCancelled = false

    func add(_ task: Task<Void, Never>) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            task.cancel()                                      // too late: cancel right away
            return
        }
        tasks.append(task)
        lock.unlock()
    }

    func cancelAll() {
        lock.lock()
        let running = tasks
        tasks = []
        isCancelled = true
        lock.unlock()
        running.forEach { $0.cancel() }
    }

    deinit { tasks.forEach { $0.cancel() } }                   // owner gone → cancel everything
}

@MainActor
final class Stats {
    static let shared = Stats()
    var finishedAfterLeaving = 0
    var cancelled = 0
}

@MainActor
final class HomeViewController {
    private let bag = TaskBag()

    func viewDidLoad() {
        for item in ["balance", "cards", "offers"] {
            bag.add(Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(1))
                    Stats.shared.finishedAfterLeaving += 1
                    self?.render(item)
                } catch {
                    Stats.shared.cancelled += 1
                }
            })
        }
    }

    func render(_ item: String) { print("render \(item)") }
    deinit { print("HomeViewController freed → its TaskBag cancels 3 requests") }
}

@MainActor
func demo() async throws {
    var screen: HomeViewController? = HomeViewController()
    screen?.viewDidLoad()
    try await Task.sleep(for: .milliseconds(200))
    screen = nil
    print("user left the screen")
    try await Task.sleep(for: .seconds(1.5))
    print("downloads finished after leaving: \(Stats.shared.finishedAfterLeaving), cancelled: \(Stats.shared.cancelled) ✅")
}

try await demo()
```

**Output**

```text
HomeViewController freed → its TaskBag cancels 3 requests
user left the screen
downloads finished after leaving: 0, cancelled: 3 ✅
```
<!-- /example -->

---

## 16.5 A timer that can't leak its owner

**In Telegram:** `Timer` is built on `DispatchSource.makeTimerSource`.
- **Thread safety:** the source lives in an `Atomic`, so `invalidate()` works from any thread.
- **No cycle:** the event handler captures `[weak self]`.
- **Self-cleaning:** `deinit` invalidates the timer.

**Why it matters:**
- **OTP countdowns, session-timeout timers and balance polling** are everywhere in banking apps.
- **The trap:** a timer that holds its owner strongly keeps the screen, and its sensitive data, alive. Foundation's `Timer(target: self, …)` retains its target, so it has the same problem.

### ❌ Bad

<!-- example: examples/16-telegram-patterns/05-timer-bad.swift -->
```swift
// ❌ BAD: a repeating timer whose handler holds `self` strongly → timer and screen keep each other alive.
//         The "Resend code" countdown keeps ticking after the user left, and the screen stays in memory
//         until the timer stops. A timer that never stops (e.g. balance polling) leaks the screen forever.
//         (Foundation's Timer.scheduledTimer(target: self, …) has the same problem: it retains its target.)
// Run: swift examples/16-telegram-patterns/05-timer-bad.swift
import Foundation

final class OTPViewController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.mybank.otp-timer")
    private var timer: DispatchSourceTimer?
    private var secondsLeft = 5

    func startCountdown() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.3, repeating: 0.3)          // 0.3 s stands in for 1 s
        timer.setEventHandler {
            self.tick()                                                 // ❌ strong self
        }
        timer.resume()
        self.timer = timer
    }

    private func tick() {
        secondsLeft -= 1
        print(secondsLeft > 0 ? "Resend code in \(secondsLeft)s" : "Resend enabled")
        if secondsLeft == 0 { timer?.cancel() }
    }

    deinit { print("OTPViewController freed") }
}

var screen: OTPViewController? = OTPViewController()
screen?.startCountdown()
Thread.sleep(forTimeInterval: 0.75)
screen = nil
print("— user left the OTP screen —")
Thread.sleep(forTimeInterval: 1.3)
print("…it kept ticking for a screen nobody sees, and was only freed when the countdown ended ❌")
```

**Output**

```text
Resend code in 4s
Resend code in 3s
— user left the OTP screen —
Resend code in 2s
Resend code in 1s
Resend enabled
OTPViewController freed
…it kept ticking for a screen nobody sees, and was only freed when the countdown ended ❌
```
<!-- /example -->

### ✅ Our version: `RepeatingTimer`

<!-- example: examples/16-telegram-patterns/05-timer-good.swift -->
```swift
// ✅ IDEA FROM TELEGRAM (SwiftSignalKit `Timer`): a DispatchSource timer whose handler holds the owner WEAKLY,
//    and which cancels itself in deinit. Leaving the screen stops the countdown. Written from scratch.
// Run: swift examples/16-telegram-patterns/05-timer-good.swift
import Foundation

final class RepeatingTimer: @unchecked Sendable {
    private let source: DispatchSourceTimer

    init(interval: TimeInterval, queue: DispatchQueue, handler: @escaping @Sendable () -> Void) {
        source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + interval, repeating: interval)
        source.setEventHandler(handler: handler)
        source.resume()
    }

    func invalidate() { source.cancel() }

    deinit { source.cancel() }                                          // owner gone → timer stops
}

final class OTPViewController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.mybank.otp-timer")
    private var timer: RepeatingTimer?
    private var secondsLeft = 5

    func startCountdown() {
        timer = RepeatingTimer(interval: 0.3, queue: queue) { [weak self] in
            self?.tick()                                                // ✅ weak self
        }
    }

    private func tick() {
        secondsLeft -= 1
        print(secondsLeft > 0 ? "Resend code in \(secondsLeft)s" : "Resend enabled")
        if secondsLeft == 0 { timer?.invalidate() }
    }

    deinit { print("OTPViewController freed ✅ (its timer is cancelled too)") }
}

var screen: OTPViewController? = OTPViewController()
screen?.startCountdown()
Thread.sleep(forTimeInterval: 0.75)
screen = nil
print("— user left the OTP screen —")
Thread.sleep(forTimeInterval: 1.3)
print("…silence: nothing keeps running after the screen is gone")
```

**Output**

```text
Resend code in 4s
Resend code in 3s
OTPViewController freed ✅ (its timer is cancelled too)
— user left the OTP screen —
…silence: nothing keeps running after the screen is gone
```
<!-- /example -->

---

## 16.6 An observable value done right

**In Telegram:**
- `ValuePromise` ignores a value equal to the current one (`ignoreRepeated`) and replays the current value to new subscribers.
- `ValuePipe` **copies the subscriber list under the lock, then calls the subscribers outside it**.

**Why it matters:**
- **Wasted work:** the balance socket often repeats the same value, and every re-render is wasted main-thread time ([10](10-performance-and-rendering.md)).
- **Deadlocks:** calling unknown code while holding a lock is how they happen. The callback might read the value, which needs the same lock.

### ❌ Bad

<!-- example: examples/16-telegram-patterns/06-observable-bad.swift -->
```swift
// ❌ BAD: a naive observable: re-renders for values that didn't change, and calls observers while
//         holding its lock (an observer that reads `value` inside its callback would deadlock)
// Run: swift examples/16-telegram-patterns/06-observable-bad.swift
import Foundation

final class NaiveObservable<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Value
    private var observers: [@Sendable (Value) -> Void] = []

    init(_ value: Value) { current = value }

    func observe(_ observer: @escaping @Sendable (Value) -> Void) {
        lock.lock(); observers.append(observer); lock.unlock()       // ❌ no way to stop observing
    }

    func set(_ newValue: Value) {
        lock.lock()
        current = newValue
        observers.forEach { $0(newValue) }                          // ❌ every value, and inside the lock
        lock.unlock()
    }
}

let balance = NaiveObservable("$1,250.50")
balance.observe { value in print("render balance \(value)") }

// The balance socket pushes the same value again and again
for value in ["$1,250.50", "$1,250.50", "$1,250.50", "$1,300.00"] {
    balance.set(value)
}
print("→ 4 renders for 1 real change ❌")
```

**Output**

```text
render balance $1,250.50
render balance $1,250.50
render balance $1,250.50
render balance $1,300.00
→ 4 renders for 1 real change ❌
```
<!-- /example -->

### ✅ Our version: `ObservableValue` + `ObservationToken`

<!-- example: examples/16-telegram-patterns/06-observable-good.swift -->
```swift
// ✅ IDEAS FROM TELEGRAM (`ValuePromise` + `ValuePipe`): ignore repeated values, replay the current value
//    to new observers, copy observers under the lock but CALL them outside it, and stop observing when
//    a token is released. Written from scratch.
// Run: swift examples/16-telegram-patterns/06-observable-good.swift
import Foundation

final class ObservationToken: Sendable {
    private let onRelease: @Sendable () -> Void
    init(_ onRelease: @escaping @Sendable () -> Void) { self.onRelease = onRelease }
    deinit { onRelease() }                                        // releasing the token stops the observation
}

final class ObservableValue<Value: Equatable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Value
    private var observers: [UUID: @Sendable (Value) -> Void] = [:]

    init(_ value: Value) { current = value }

    var value: Value { lock.lock(); defer { lock.unlock() }; return current }

    func set(_ newValue: Value) {
        lock.lock()
        guard newValue != current else { lock.unlock(); return }     // ✅ nothing changed → nobody is called
        current = newValue
        let toNotify = Array(observers.values)                       // ✅ copy under the lock…
        lock.unlock()
        toNotify.forEach { $0(newValue) }                            // …call outside it
    }

    func observe(_ observer: @escaping @Sendable (Value) -> Void) -> ObservationToken {
        let id = UUID()
        lock.lock()
        observers[id] = observer
        let initial = current
        lock.unlock()
        observer(initial)                                            // ✅ new observers get the current value
        return ObservationToken { [weak self] in self?.removeObserver(id) }
    }

    private func removeObserver(_ id: UUID) {
        lock.lock(); observers[id] = nil; lock.unlock()
    }
}

let balance = ObservableValue("$1,250.50")
var token: ObservationToken? = balance.observe { value in
    print("render balance \(value) (reading .value inside the callback is safe: \(balance.value))")
}

for value in ["$1,250.50", "$1,250.50", "$1,250.50", "$1,300.00"] {
    balance.set(value)
}
print("→ 2 renders: the initial value + 1 real change ✅")

token = nil                                                          // the screen went away
balance.set("$1,400.00")
print("after releasing the token: no more renders ✅")
_ = token
```

**Output**

```text
render balance $1,250.50 (reading .value inside the callback is safe: $1,250.50)
render balance $1,300.00 (reading .value inside the callback is safe: $1,300.00)
→ 2 renders: the initial value + 1 real change ✅
after releasing the token: no more renders ✅
```
<!-- /example -->

> **Rule worth memorizing:** never call out to unknown code (callbacks, delegates, notifications) while holding a lock. Copy what you need, unlock, then call.

---

## 16.7 Coalesce many updates into one UI update

**In Telegram:** `debounceOnMainThread` keeps only the **latest** value in an `Atomic`. The first value of a burst schedules **one** `DispatchQueue.main.async` flush; later values just replace the pending one. This isn't time-based: it merges everything that happens before the main queue's next turn.

**Why it matters:** a sync response that updates 5 accounts one by one shouldn't reload the list 5 times.

### ❌ Bad

<!-- example: examples/16-telegram-patterns/07-coalesce-bad.swift -->
```swift
// ❌ BAD: every model change schedules its own UI reload → 5 reloads in one run-loop turn
// Run: swift examples/16-telegram-patterns/07-coalesce-bad.swift
import Foundation

final class AccountsScreen: @unchecked Sendable {
    func accountsDidChange(_ snapshot: [String]) {
        DispatchQueue.main.async {
            print("reload list (\(snapshot.count) accounts)")     // ❌ one reload per change
        }
    }
}

let screen = AccountsScreen()
DispatchQueue.main.async {
    // A sync response updates 5 accounts one after another, all in one turn of the main queue
    var accounts: [String] = []
    for name in ["Savings USD", "Current USD", "Savings KHR", "Current KHR", "Loan"] {
        accounts.append(name)
        screen.accountsDidChange(accounts)
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    print("→ 5 reloads; only the last one mattered ❌")
    exit(0)
}
dispatchMain()
```

**Output**

```text
reload list (1 accounts)
reload list (2 accounts)
reload list (3 accounts)
reload list (4 accounts)
reload list (5 accounts)
→ 5 reloads; only the last one mattered ❌
```
<!-- /example -->

### ✅ Our version: `MainQueueCoalescer`

<!-- example: examples/16-telegram-patterns/07-coalesce-good.swift -->
```swift
// ✅ IDEA FROM TELEGRAM (`debounceOnMainThread`): keep only the LATEST value and schedule ONE main-queue
//    flush per burst → many changes in the same turn become one UI update. Written from scratch.
// Run: swift examples/16-telegram-patterns/07-coalesce-good.swift
import Foundation

final class MainQueueCoalescer<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: Value?
    private let deliver: @Sendable (Value) -> Void              // called on the main queue

    init(deliver: @escaping @Sendable (Value) -> Void) { self.deliver = deliver }

    func send(_ value: Value) {
        lock.lock()
        let flushAlreadyScheduled = pending != nil
        pending = value                                         // newer value replaces the older one
        lock.unlock()
        if !flushAlreadyScheduled {
            DispatchQueue.main.async { self.flush() }
        }
    }

    private func flush() {
        lock.lock()
        let value = pending
        pending = nil
        lock.unlock()
        if let value { deliver(value) }
    }
}

final class AccountsScreen: @unchecked Sendable {
    private lazy var reloads = MainQueueCoalescer<[String]> { snapshot in
        print("reload list (\(snapshot.count) accounts)")      // ✅ once per burst, with the newest data
    }

    func accountsDidChange(_ snapshot: [String]) { reloads.send(snapshot) }
}

let screen = AccountsScreen()
DispatchQueue.main.async {
    var accounts: [String] = []
    for name in ["Savings USD", "Current USD", "Savings KHR", "Current KHR", "Loan"] {
        accounts.append(name)
        screen.accountsDidChange(accounts)
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    print("→ 1 reload with all 5 accounts ✅")
    exit(0)
}
dispatchMain()
```

**Output**

```text
reload list (5 accounts)
→ 1 reload with all 5 accounts ✅
```
<!-- /example -->

**Coalesce vs debounce:**
- **Coalesce** (this): merge what happens *in the same turn*; no delay.
- **Debounce** ([15.7](15-gcd.md#157-debounce-with-dispatchworkitem)): wait until input *stops* for some time.

---

## 16.8 Throttle repeated taps

**In Telegram:** `Throttler` runs the first value immediately, suppresses the rest for a window (0.25 s by default), and then also emits the **last** suppressed value.

**Why it matters:** "Resend OTP" tapped four times shouldn't send four SMS.

### ❌ Bad

<!-- example: examples/16-telegram-patterns/08-throttle-bad.swift -->
```swift
// ❌ BAD: no protection against repeated taps → an impatient user triggers 4 OTP SMS in under a second
// Run: swift examples/16-telegram-patterns/08-throttle-bad.swift
import Foundation

@MainActor
final class OTPViewController {
    private var smsSent = 0

    func resendTapped(at time: String) {
        smsSent += 1
        print("\(time): 📩 SMS #\(smsSent) sent")                // ❌ every tap costs an SMS
    }
}

@MainActor
func demo() async throws {
    let screen = OTPViewController()
    let start = ContinuousClock.now
    for delay in [0, 100, 200, 700] {                           // taps at 0, 0.1, 0.2 and 0.7 s
        try await Task.sleep(until: start + .milliseconds(delay), clock: .continuous)
        screen.resendTapped(at: "\(delay) ms")
    }
}

try await demo()
```

**Output**

```text
0 ms: 📩 SMS #1 sent
100 ms: 📩 SMS #2 sent
200 ms: 📩 SMS #3 sent
700 ms: 📩 SMS #4 sent
```
<!-- /example -->

### ✅ Our version: leading-edge `Throttler`

<!-- example: examples/16-telegram-patterns/08-throttle-good.swift -->
```swift
// ✅ IDEA FROM TELEGRAM (`Throttler`, simplified): leading-edge throttle: the first tap runs now, taps
//    inside the window are ignored. Telegram's version also replays the LAST value at the end of the window;
//    for "send an SMS" we deliberately don't. Written from scratch.
// Run: swift examples/16-telegram-patterns/08-throttle-good.swift
import Foundation

@MainActor
final class Throttler {
    private let interval: Duration
    private var lastRun: ContinuousClock.Instant?

    init(interval: Duration) { self.interval = interval }

    /// Runs `action` unless it already ran less than `interval` ago. Returns whether it ran.
    @discardableResult
    func run(_ action: () -> Void) -> Bool {
        let now = ContinuousClock.now
        if let lastRun, now - lastRun < interval { return false }
        lastRun = now
        action()
        return true
    }
}

@MainActor
final class OTPViewController {
    private let resendThrottle = Throttler(interval: .milliseconds(500))   // real app: 30–60 s, plus a server limit
    private var smsSent = 0

    func resendTapped(at time: String) {
        let sent = resendThrottle.run {
            smsSent += 1
            print("\(time): 📩 SMS #\(smsSent) sent")
        }
        if !sent { print("\(time): ignored (too soon)") }
    }
}

@MainActor
func demo() async throws {
    let screen = OTPViewController()
    let start = ContinuousClock.now
    for delay in [0, 100, 200, 700] {
        try await Task.sleep(until: start + .milliseconds(delay), clock: .continuous)
        screen.resendTapped(at: "\(delay) ms")
    }
}

try await demo()
```

**Output**

```text
0 ms: 📩 SMS #1 sent
100 ms: ignored (too soon)
200 ms: ignored (too soon)
700 ms: 📩 SMS #2 sent
```
<!-- /example -->

**What we changed, and why:**
- **No trailing emit.** For actions that cost money or send SMS, replaying the last tap is the wrong behaviour. Telegram's version suits UI values like a slider.
- **Thread safety.** Telegram's source has a `TODO: quick fix, replace with timer`, and some of its methods touch state outside its queue. Ours is `@MainActor`, so the compiler guards the state.
- **Server limits.** A client-side throttle is UX only. The **server** must also rate-limit OTPs.

---

## 16.9 One layout function, immediate or animated

**In Telegram:** almost every screen has a layout method that receives a `ContainedViewLayoutTransition`, which is either `.immediate` or `.animated(duration:curve:)`. Helpers like [`updateFrame(view:frame:)`](https://github.com/TelegramMessenger/Telegram-iOS/blob/f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838/submodules/Display/Source/ContainedViewLayoutTransition.swift#L910) do three things:
- **Reject bad frames:** NaN or negative frames are ignored.
- **Skip no-ops:** if the view is already at the target frame, nothing happens.
- **Continue smoothly:** when the transition is animated, it can start from the *on-screen* (presentation) value.

**Why it's clever:**
- **One layout path.** The *same* layout code runs for the first layout, rotation, keyboard changes and user taps. There's no separate "animated version" that drifts out of sync.
- **The no-op check matters too.** It makes calling `layout(.immediate)` from `viewDidLayoutSubviews` during an animation harmless.

### ✅ Our version (🍎 Playground: tap the card)

<!-- playground: examples/16-telegram-patterns/playground/09-layout-transition-good.swift -->
```swift
// ✅ IDEA FROM TELEGRAM (`ContainedViewLayoutTransition` in submodules/Display): write ONE layout function and
//    pass it a transition: `.immediate` for first layout and rotation, `.animated` when the user taps.
//    Same code, no duplicated "animated" branch. Written from scratch for this guide; not Telegram's code.
// 🍎 Paste into an Xcode iOS Playground. Tap the card to expand and collapse it.
import UIKit
import PlaygroundSupport

@MainActor
enum LayoutTransition {
    case immediate
    case animated(duration: TimeInterval, curve: UIView.AnimationCurve = .easeInOut)

    func updateFrame(of view: UIView, to frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        // Never apply NaN or negative frames (a bad frame can corrupt Core Animation state)
        guard frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width.isFinite, frame.height.isFinite,
              frame.width >= 0, frame.height >= 0 else { return }
        guard view.frame != frame else {           // already there: no animation, no work
            completion?(true)
            return
        }
        perform({ view.frame = frame }, completion: completion)
    }

    func updateAlpha(of view: UIView, to alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        guard view.alpha != alpha else {
            completion?(true)
            return
        }
        perform({ view.alpha = alpha }, completion: completion)
    }

    private func perform(_ changes: @escaping () -> Void, completion: ((Bool) -> Void)?) {
        switch self {
        case .immediate:
            changes()
            completion?(true)
        case let .animated(duration, curve):
            // UIViewPropertyAnimator starts from what's on screen now, so a second tap mid-animation
            // smoothly reverses instead of jumping (Telegram's `beginWithCurrentState`)
            let animator = UIViewPropertyAnimator(duration: duration, curve: curve, animations: changes)
            animator.addCompletion { position in completion?(position == .end) }
            animator.startAnimation()
        }
    }
}

final class AccountCardViewController: UIViewController {
    private let card = UIView()
    private let balanceLabel = UILabel()
    private let detailsLabel = UILabel()
    private var isExpanded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        card.backgroundColor = .systemBlue
        card.layer.cornerRadius = 16
        card.clipsToBounds = true

        balanceLabel.text = "$1,250.50"
        balanceLabel.textColor = .white
        balanceLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)

        detailsLabel.text = "Account •••• 3456\nAvailable  $1,200.00\nOn hold      $50.50"
        detailsLabel.numberOfLines = 0
        detailsLabel.textColor = .white
        detailsLabel.alpha = 0

        view.addSubview(card)
        card.addSubview(balanceLabel)
        card.addSubview(detailsLabel)
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped)))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layout(size: view.bounds.size, transition: .immediate)        // first layout, rotation: no animation
    }

    @objc private func cardTapped() {
        isExpanded.toggle()
        layout(size: view.bounds.size, transition: .animated(duration: 0.35))   // same function, animated
    }

    /// The ONE place that knows where everything goes.
    private func layout(size: CGSize, transition: LayoutTransition) {
        let inset: CGFloat = 16
        let cardWidth = size.width - inset * 2
        let cardHeight: CGFloat = isExpanded ? 200 : 104

        transition.updateFrame(of: card, to: CGRect(x: inset, y: view.safeAreaInsets.top + inset,
                                                    width: cardWidth, height: cardHeight))
        balanceLabel.frame = CGRect(x: 20, y: 24, width: cardWidth - 40, height: 40)
        detailsLabel.frame = CGRect(x: 20, y: 76, width: cardWidth - 40, height: 100)
        transition.updateAlpha(of: detailsLabel, to: isExpanded ? 1 : 0)
    }
}

let viewController = AccountCardViewController()
viewController.preferredContentSize = CGSize(width: 390, height: 500)
PlaygroundPage.current.liveView = viewController
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

**Trade-off:** Telegram lays out with **manual frames**, which is fast and exact. You then handle Dynamic Type, right-to-left languages and size changes yourself. For most banking screens, Auto Layout ([05 · 5.3](05-uikit.md#53-auto-layout)) is the safer default. Keep manual layout for heavy custom views.

---

## 16.10 Small UIKit helpers

**In Telegram:**
- `HapticFeedback` caches one generator per style and `prepare()`s it before use.
- `UIColor(rgb:)` turns designer hex values into colors.
- `generateImage` draws images in code.
- `UIResponder.currentFirst()` finds the active text field with `UIApplication.sendAction(_:to: nil, …)`.

### ✅ Our versions (🍎)

<!-- snippet: examples/16-telegram-patterns/apple-only/UIKitHelpers.swift -->
```swift
// ✅ Small UIKit helpers inspired by Telegram's Display module (UIKitUtils.swift, HapticFeedback.swift,
//    GenerateImage.swift, KeyboardManager.swift). Written from scratch for this guide; not Telegram's code.
// 🍎 iOS only. Not run in this guide's Linux test.
import UIKit

// MARK: - Colors straight from the designer's hex values

extension UIColor {
    /// UIColor(rgb: 0x0A84FF)
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - Haptics: one cached generator per style, prepared before use

@MainActor
final class Haptics {
    static let shared = Haptics()

    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    /// Call when a haptic is about to happen (finger down on a PIN key) to cut latency.
    func prepareImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        impactGenerator(for: style).prepare()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        impactGenerator(for: style).impactOccurred()
    }

    func success() { notificationGenerator.notificationOccurred(.success) }   // transfer completed
    func error() { notificationGenerator.notificationOccurred(.error) }       // wrong PIN
    func selection() { selectionGenerator.selectionChanged() }                // picker / segmented change

    private func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let existing = impactGenerators[style] { return existing }
        let created = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style] = created
        return created
    }
}

// MARK: - Generated images: initials avatar for payees without a photo ("Sok Dara" → "SD")

func initialsAvatar(for name: String, diameter: CGFloat = 44, color: UIColor = UIColor(rgb: 0x0A84FF)) -> UIImage {
    let initials = name.split(separator: " ")
        .prefix(2)
        .compactMap(\.first)
        .map(String.init)
        .joined()
        .uppercased()
    let size = CGSize(width: diameter, height: diameter)

    return UIGraphicsImageRenderer(size: size).image { _ in
        color.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: diameter * 0.4, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
        let text = initials as NSString
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                  withAttributes: attributes)
    }
}

// MARK: - Dismiss the keyboard from anywhere

extension UIApplication {
    /// Sends `resignFirstResponder` up the responder chain: whichever field is editing gives up the keyboard,
    /// without needing a reference to it. (Telegram uses the same sendAction(to: nil) trick to FIND
    /// the first responder.)
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
```
<!-- /snippet -->

---

## Reading other people's code critically

Telegram is excellent code, but not every line is a model to copy. While verifying the search results, we noticed:
- **Lock address:** `Atomic` stores a `pthread_mutex_t` as a property, and Swift doesn't guarantee its address stays fixed ([16.2](#162-atomic-a-value-and-its-lock-together)).
- **Naming:** `Queue.async` may run synchronously ([16.1](#161-a-serial-queue-that-knows-where-it-is)).
- **Known shortcuts:** `Throttler` carries a `TODO` and touches some state outside its queue ([16.8](#168-throttle-repeated-taps)).
- **Unexplained code:** `HapticFeedback`'s `deinit` waits 1 second and calls an empty method, with no comment saying why.

Big apps accumulate trade-offs and history. Take the *idea*, check it against current Swift (Swift 6 concurrency, `Mutex`, actors), and write it in a form your team can review.

**Practice**

- [ ] Open the linked Telegram files and compare them line by line with our versions. List one more difference.
- [ ] Combine 16.3 and 16.4: a screen with a `LatestTask` for search and a `TaskBag` for everything else.
- [ ] Use `RepeatingTimer` to build a 5-minute inactivity auto-logout ([09](09-security.md)).
- [ ] Rewrite `ObservableValue` as an `actor` with an `AsyncStream`. What gets simpler, and what gets harder?

---

## Alternatives and trade-offs

| Need | Option | ✅ Strengths | ⚠️ Trade-offs |
|---|---|---|---|
| Reactive streams | SwiftSignalKit (Telegram's) | tiny, fast, battle-tested at huge scale | not a standalone package; Telegram's licensing |
| Reactive streams | Combine | built in, `@Published`, operators | Apple has added little to it lately |
| Reactive streams | RxSwift | huge operator set; common in older codebases | big dependency |
| Reactive streams | `AsyncSequence` / `AsyncStream` + swift-async-algorithms | modern, `async/await`-native | fewer operators; cancellation to learn |
| Cancellation | small helpers like `LatestTask` / `TaskBag` (this page) | tiny, no dependency | you maintain them |
| Cancellation | Combine `AnyCancellable` + `Set<AnyCancellable>` | standard in Combine code | Combine only |
| Locks | `NSLock` / `OSAllocatedUnfairLock` / `Mutex` | fast for tiny critical sections | easy to misuse; prefer actors for new state |
| Layout | Auto Layout | adaptive, standard | solver cost in very complex views |
| Layout | manual frames + `LayoutTransition` (Telegram style) | fastest, precise animations | you own Dynamic Type and RTL |

---

[← Index](../README.md) · [← GCD deep dive](15-gcd.md)
