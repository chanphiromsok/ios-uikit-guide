# iOS UIKit Learning Guide

**For React / React Native developers moving to native iOS, aiming at banking apps in Cambodia.**

Every topic shows a ❌ **bad** practice and a ✅ **good** one, with **complete code you can copy and run**. Run the bad one to *see* the bug, then run the good one to see the fix. Each section ends with **alternative libraries and approaches, with their trade-offs**.

```bash
# your first example (macOS/Linux with Swift, or any OS with Docker)
swift examples/02-swift/04-money-bad.swift
docker run --rm -v "$PWD":/code -w /code swift:latest swift examples/02-swift/04-money-bad.swift
```

New here? Start with **[01 · Setup and running the examples](docs/01-setup.md)**.

---

## Index

| # | Section | You'll learn | Runs on |
|---|---|---|---|
| 01 | [Setup](docs/01-setup.md) | running examples without a Mac, Docker, Playgrounds | – |
| 02 | [Swift fundamentals](docs/02-swift-fundamentals.md) | struct vs class, optionals, enum state, `Decimal` money, retain cycles, errors, DI, Codable | 🐧 |
| 03 | [Concurrency: GCD and async/await](docs/03-concurrency.md) | completion handlers, bridging, `async let` vs `DispatchGroup`, actors vs serial queues, `@MainActor` | 🐧 |
| 04 | [Networking and data](docs/04-networking-and-data.md) | API client, DTO → Domain → ViewData, caching + dedupe + invalidation, token refresh | 🐧 |
| 05 | [UIKit fundamentals](docs/05-uikit.md) | window/root, lifecycle, Auto Layout, lists + reuse, delegates, login → home, presenting, **list → detail by id** | 🍎 + 🐧 |
| 06 | [Architecture and modularization](docs/06-architecture.md) | "code splitting" on iOS, MVVM + Coordinator, the **BankKit** package with tests | 🐧 |
| 07 | [Dev and Prod environments](docs/07-environments.md) | `.xcconfig`, `Info.plist`, schemes, secrets | 🐧 + Xcode |
| 08 | [Local storage](docs/08-local-storage.md) | UserDefaults vs Keychain vs files/DB, typed settings | 🐧 + 🍎 |
| 09 | [Security for banking](docs/09-security.md) | logging, idempotent transfers, biometrics, privacy cover, pinning | 🐧 + 🍎 |
| 10 | [Performance and rendering](docs/10-performance-and-rendering.md) | **render pipeline step by step (Mermaid diagrams)**, frame budget, hitches, formatters, offscreen rendering | 🐧 + 🍎 |
| 11 | [Devtools](docs/11-devtools.md) | DevTools → Xcode mapping, LLDB, Memory Graph, Instruments, debug menu | reference |
| 12 | [Interview prep (Cambodian banks)](docs/12-interview-prep.md) | process, questions with answers, KHQR, live coding | 🐧 |
| 13 | [Capstone: MyBank](docs/13-capstone.md) | a portfolio app that uses every section | Xcode |
| 14 | [UIKit component catalog](docs/14-uikit-components.md) | every common component: banking use case, tips and tricks, gotchas, snippets | 🍎 reference |
| 15 | [GCD deep dive](docs/15-gcd.md) | queues, sync vs async, QoS, deadlocks, barriers, DispatchGroup, semaphores, thread explosion, debounce | 🐧 |
| 16 | [Patterns from Telegram iOS](docs/16-patterns-from-telegram.md) | ideas from Telegram's source rewritten for Swift 6: serial queue, Atomic, latest-only, task bag, timers, observable, coalescing, throttle, layout transitions | 🐧 + 🍎 |

**Legend:** ❌ bad · ✅ good · 👀 explore · 🐧 runs anywhere Swift runs · 🍎 needs Xcode (iOS Playground or app)

---

## All bad / good pairs

| Section | Topic | ❌ Bad | ✅ Good |
|---|---|---|---|
| 02 | struct vs class | [bad](examples/02-swift/01-struct-vs-class-bad.swift) | [good](examples/02-swift/01-struct-vs-class-good.swift) |
| 02 | Optionals | [bad](examples/02-swift/02-optionals-bad.swift) | [good](examples/02-swift/02-optionals-good.swift) |
| 02 | Screen state | [bad](examples/02-swift/03-view-state-bad.swift) | [good](examples/02-swift/03-view-state-good.swift) |
| 02 | Money | [bad](examples/02-swift/04-money-bad.swift) | [good](examples/02-swift/04-money-good.swift) |
| 02 | Retain cycles | [bad](examples/02-swift/05-retain-cycle-bad.swift) | [good](examples/02-swift/05-retain-cycle-good.swift) |
| 02 | Errors | [bad](examples/02-swift/06-errors-bad.swift) | [good](examples/02-swift/06-errors-good.swift) |
| 02 | Dependency injection | [bad](examples/02-swift/07-dependency-injection-bad.swift) | [good](examples/02-swift/07-dependency-injection-good.swift) |
| 02 | JSON / Codable | [bad](examples/02-swift/08-codable-bad.swift) | [good](examples/02-swift/08-codable-good.swift) |
| 03 | Completion handlers (GCD) | [bad](examples/03-concurrency/01-completion-handler-bad.swift) | [good](examples/03-concurrency/01-completion-handler-good.swift) |
| 03 | async/await + bridging | [bad](examples/03-concurrency/02-continuation-bad.swift) | [good](examples/03-concurrency/02-async-await-good.swift) |
| 03 | Parallel requests | [bad](examples/03-concurrency/03-parallel-bad.swift) | [good](examples/03-concurrency/03-parallel-good.swift) · [GCD](examples/03-concurrency/03-parallel-gcd-good.swift) |
| 03 | Shared state | [bad](examples/03-concurrency/04-shared-state-bad.swift) | [good](examples/03-concurrency/04-shared-state-good.swift) |
| 03 | Main thread | [bad](examples/03-concurrency/05-main-thread-bad.swift) | [good](examples/03-concurrency/05-main-thread-good.swift) |
| 04 | Fetching | [bad](examples/04-networking/01-fetch-bad.swift) | [good](examples/04-networking/01-fetch-good.swift) |
| 04 | Mapping | [bad](examples/04-networking/02-mapping-bad.swift) | [good](examples/04-networking/02-mapping-good.swift) |
| 04 | Caching | [bad](examples/04-networking/03-caching-bad.swift) | [good](examples/04-networking/03-caching-good.swift) |
| 04 | Token refresh | [bad](examples/04-networking/04-token-refresh-bad.swift) | [good](examples/04-networking/04-token-refresh-good.swift) |
| 05 | Delegates | [bad](examples/05-uikit/01-delegate-bad.swift) | [good](examples/05-uikit/01-delegate-good.swift) |
| 05 | Auto Layout 🍎 | [bad](examples/05-uikit/playground/02-autolayout-bad.swift) | [good](examples/05-uikit/playground/02-autolayout-good.swift) |
| 05 | Lists and reuse 🍎 | [bad](examples/05-uikit/playground/03-list-bad.swift) | [good](examples/05-uikit/playground/03-list-good.swift) |
| 05 | Login → Home 🍎 | [bad](examples/05-uikit/playground/04-root-swap-bad.swift) | [good](examples/05-uikit/playground/04-root-swap-good.swift) |
| 05 | Presenting 🍎 | [bad](examples/05-uikit/playground/05-present-top-bad.swift) | [good](examples/05-uikit/playground/05-present-top-good.swift) |
| 05 | List → Detail by id | [bad](examples/05-uikit/07-detail-by-id-bad.swift) | [good](examples/05-uikit/07-detail-by-id-good.swift) · [UIKit 🍎](examples/05-uikit/playground/07-list-detail-good.swift) |
| 06 | Massive VC → MVVM | [bad](examples/06-architecture/01-massive-view-controller-bad.swift) | [good](examples/06-architecture/01-mvvm-good.swift) |
| 07 | Environments | [bad](examples/07-environments/01-environment-bad.swift) | [good](examples/07-environments/01-environment-good.swift) |
| 08 | Token storage | [bad](examples/08-storage/01-token-storage-bad.swift) | [good 🍎](examples/08-storage/apple-only/KeychainStore.swift) |
| 08 | Settings | [bad](examples/08-storage/02-settings-bad.swift) | [good](examples/08-storage/02-settings-good.swift) |
| 09 | Logging | [bad](examples/09-security/01-logging-bad.swift) | [good](examples/09-security/01-logging-good.swift) |
| 09 | Idempotent transfers | [bad](examples/09-security/02-idempotency-bad.swift) | [good](examples/09-security/02-idempotency-good.swift) |
| 10 | Formatters | [bad](examples/10-performance/01-formatter-bad.swift) | [good](examples/10-performance/01-formatter-good.swift) |
| 15 | GCD: queues 👀 | – | [explore](examples/15-gcd/01-queues-explore.swift) |
| 15 | GCD: sync deadlock | [bad](examples/15-gcd/02-sync-deadlock-bad.swift) | [good](examples/15-gcd/02-sync-deadlock-good.swift) |
| 15 | GCD: thread-safe state | [bad](examples/15-gcd/03-concurrent-queue-bad.swift) | [good](examples/15-gcd/03-concurrent-queue-good.swift) |
| 15 | GCD: DispatchGroup | [bad](examples/15-gcd/04-group-leave-bad.swift) | [good](examples/15-gcd/04-group-leave-good.swift) |
| 15 | GCD: semaphores | [bad](examples/15-gcd/05-semaphore-main-bad.swift) | [good](examples/15-gcd/05-semaphore-main-good.swift) |
| 15 | GCD: blocking threads | [bad](examples/15-gcd/06-blocking-threads-bad.swift) | [good](examples/15-gcd/06-blocking-threads-good.swift) |
| 15 | GCD: debounce | [bad](examples/15-gcd/07-debounce-bad.swift) | [good](examples/15-gcd/07-debounce-good.swift) |
| 16 | Serial queue that knows "am I on it?" | – | [good](examples/16-telegram-patterns/01-serial-queue-good.swift) |
| 16 | Atomic value | – | [good](examples/16-telegram-patterns/02-atomic-good.swift) |
| 16 | Latest-only job | [bad](examples/16-telegram-patterns/03-latest-only-bad.swift) | [good](examples/16-telegram-patterns/03-latest-only-good.swift) |
| 16 | Task bag | [bad](examples/16-telegram-patterns/04-task-bag-bad.swift) | [good](examples/16-telegram-patterns/04-task-bag-good.swift) |
| 16 | Timer without leaks | [bad](examples/16-telegram-patterns/05-timer-bad.swift) | [good](examples/16-telegram-patterns/05-timer-good.swift) |
| 16 | Observable value | [bad](examples/16-telegram-patterns/06-observable-bad.swift) | [good](examples/16-telegram-patterns/06-observable-good.swift) |
| 16 | Coalesce UI updates | [bad](examples/16-telegram-patterns/07-coalesce-bad.swift) | [good](examples/16-telegram-patterns/07-coalesce-good.swift) |
| 16 | Throttle taps | [bad](examples/16-telegram-patterns/08-throttle-bad.swift) | [good](examples/16-telegram-patterns/08-throttle-good.swift) |
| 16 | Layout transition 🍎 | – | [good](examples/16-telegram-patterns/playground/09-layout-transition-good.swift) |

---

## Progress

- [ ] 01 Setup
- [ ] 02 Swift fundamentals
- [ ] 03 Concurrency
- [ ] 04 Networking and data
- [ ] 05 UIKit fundamentals
- [ ] 06 Architecture
- [ ] 07 Environments
- [ ] 08 Local storage
- [ ] 09 Security
- [ ] 10 Performance and rendering
- [ ] 11 Devtools
- [ ] 12 Interview prep
- [ ] 13 Capstone shipped to TestFlight
- [ ] 14 Component catalog: built one screen with each category
- [ ] 15 GCD deep dive
- [ ] 16 Patterns from Telegram iOS

## Roadmap

| Weeks | Focus | Sections |
|---|---|---|
| 1–3 | Swift + concurrency (works on Linux/Windows) | 02, 03, 15, 04 |
| 4–7 | UIKit screens in code | 05 |
| 8–10 | Architecture, environments, storage, tests | 06, 07, 08 |
| 11–14 | Security, performance, capstone, interviews | 09, 10, 11, 12, 13, 16 |

## How the examples were tested

- **🐧 examples:** every file was run with **Swift 6.4.1** (official Docker image, Linux), in both Swift 5 and Swift 6 language modes. The **Output** blocks in the docs come from those runs. Outputs marked "numbers change on every run" depend on timing or thread scheduling.
- **BankKit:** `swift test` passes (12 tests).
- **🍎 files** (`playground/`, `apple-only/`) need Apple's SDKs and were **not compiled** in that environment. They use standard UIKit/Security APIs, but if Xcode reports an error, the fix is usually small.

## Resources

- **Swift and UIKit:**
  - [The Swift Programming Language](https://docs.swift.org/swift-book/)
  - [UIKit documentation](https://developer.apple.com/documentation/uikit)
  - [100 Days of Swift](https://www.hackingwithswift.com/100) (UIKit-based, free)
  - [Kodeco](https://www.kodeco.com)
  - [Swift by Sundell](https://www.swiftbysundell.com)
- **WWDC sessions:** *Meet async/await in Swift* (2021), *Protect mutable state with Swift actors* (2021), *Lists in UICollectionView* (2020), *Modern cell configuration* (2020), *Analyze HTTP traffic in Instruments* (2021), *Detect and diagnose memory issues* (2021), *What's new in UIKit* (2025)
- **Security:** [OWASP MAS (MASVS / MASTG)](https://mas.owasp.org)
- **Tools:** Proxyman, Pulse, SwiftLint, swift-format, Fastlane, InjectionIII
