# 01 · Setup and running the examples

[← Index](../README.md) · [Next: Swift fundamentals →](02-swift-fundamentals.md)

---

## You don't need a Mac to start

Xcode only runs on macOS, so **UIKit screens need a Mac**. Everything else (Swift, concurrency, networking, data mapping, caching, security logic, tests) runs on **macOS, Linux or Windows**. Most examples in this guide are written that way on purpose.

| Option | What you can run |
|---|---|
| **Swift on Linux/Windows** ([swift.org/install](https://www.swift.org/install)) + the VS Code Swift extension | Every 🐧 example and the `BankKit` package tests |
| **Docker** (any OS) | Same as above, no install: uses the official `swift` image |
| **Mac with Xcode** | Everything, including 🍎 Playground screens |
| **iPad + Swift Playgrounds** | Most 🍎 Playground screens |
| **Cloud Mac** (MacinCloud, AWS EC2 Mac) | Occasional full Xcode sessions |

## Legend

| Icon | Meaning |
|---|---|
| ❌ **BAD** | A common mistake. Run it to *see* the bug. |
| ✅ **GOOD** | The best-practice version. Copy this one. |
| 🐧 | Runs anywhere Swift runs (`swift file.swift`) |
| 🍎 | Needs Xcode: paste into an iOS Playground or an app |
| 👀 | Explore: no bad/good, just watch what happens |

## Run one example

From the `ios-uikit-guide` folder:

```bash
# macOS / Linux with Swift installed
swift examples/02-swift/01-struct-vs-class-bad.swift

# Any OS with Docker (PowerShell: replace "$PWD" with "${PWD}")
docker run --rm -v "$PWD":/code -w /code swift:latest swift examples/02-swift/01-struct-vs-class-bad.swift
```

Every file starts with a `// Run:` line with its exact command.

## Run all examples

```bash
./scripts/run-all.sh              # everything that runs without Xcode
./scripts/run-all.sh 04-networking  # only one section
```

It uses your local `swift` if you have it, otherwise Docker.

## Run the BankKit package tests

```bash
cd examples/06-architecture/BankKit
swift test
# or: docker run --rm -v "$PWD":/pkg -w /pkg swift:latest swift test
```

## Run a 🍎 Playground screen

1. Xcode → **File → New → Playground → iOS → Blank**.
2. Delete the template code and paste the whole example file.
3. Press ▶ (Run). Show the screen with **Editor → Live View** (⌥⌘↩). `print` output appears in the debug area at the bottom.

## Folder layout

```
ios-uikit-guide/
├── README.md                 ← index
├── docs/                     ← one page per topic (you are here)
├── examples/
│   ├── 02-swift/             ← 🐧 *-bad.swift / *-good.swift pairs
│   ├── 03-concurrency/
│   ├── 04-networking/
│   ├── 05-uikit/
│   │   └── playground/       ← 🍎 paste into an iOS Playground
│   ├── 06-architecture/
│   │   └── BankKit/          ← 🐧 a real Swift Package with tests
│   ├── 07-environments/Config/   ← .xcconfig files to copy into your project
│   ├── 08-storage/apple-only/    ← 🍎 Keychain
│   ├── 09-security/apple-only/   ← 🍎 Face ID, privacy cover, pinning
│   ├── 10-performance/
│   └── 12-interview/
└── scripts/run-all.sh
```

> **How the examples were checked:** every 🐧 file was run with **Swift 6.4.1** (Docker, Linux) in both Swift 5 and Swift 6 language modes, and the **Output** blocks in these pages are copied from those runs. 🍎 files need Apple's SDKs and could not be compiled in that environment. They use standard UIKit APIs, but if Xcode reports an error, the fix is usually small.

**Practice**

- [ ] Run `01-struct-vs-class-bad.swift` and `01-struct-vs-class-good.swift` and compare the output.
- [ ] Run `./scripts/run-all.sh 02-swift`.
- [ ] Run the BankKit tests.

---

## Alternatives and trade-offs

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| Swift toolchain on Linux/Windows | free, fast, real compiler + tests | no UIKit, no Simulator | you're learning Swift and the data layer without a Mac |
| Docker `swift` image | nothing to install except Docker; same version for everyone | slower start per run; no UIKit | you want the exact setup used to test this guide |
| iPad + Swift Playgrounds | real UIKit/SwiftUI on device, cheap if you own an iPad | limited debugging, no Instruments, small screen | you want to see screens before buying a Mac |
| Cloud Mac (MacinCloud, AWS EC2 Mac) | full Xcode | monthly/hourly cost; latency; AWS has a 24-hour minimum | occasional builds, or CI |
| Used Apple Silicon Mac (M1+) | everything works, offline | upfront cost | you're committing to iOS (you'll need one for any job) |

---

[← Index](../README.md) · [Next: Swift fundamentals →](02-swift-fundamentals.md)
