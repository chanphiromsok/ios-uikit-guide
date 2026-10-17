# 13 · Capstone project: MyBank

[← Index](../README.md) · [← Interview prep](12-interview-prep.md)

A mock banking app that uses every section of this guide. Start from [`BankKit`](../examples/06-architecture/BankKit) for the Core layer. Back it with JSON fixtures (a mock API in the Dev scheme) or a tiny Node server.

## Suggested structure

```
MyBank.xcodeproj
├── App/                    AppDelegate, SceneDelegate, AppCoordinator, AppEnvironment   (05, 06, 07)
├── Config/                 Shared / Dev / Prod .xcconfig                                 (07)
└── Packages/BankKit/
    ├── Networking          APIClient, TokenProvider                                     (04)
    ├── Banking             Money, mapping, repositories                                  (04)
    ├── Security            KeychainStore, biometric token, Redact                        (08, 09)
    ├── DesignSystem        colors, fonts, buttons, Khmer-safe label styles
    └── Features
        ├── LoginFeature
        ├── AccountsFeature
        ├── TransactionsFeature   list → detail by id                                     (05 · 5.8)
        ├── TransferFeature       idempotency key                                         (09 · 9.2)
        └── KHQRFeature           TLV parse + CRC                                         (12)
```

## Features

- [ ] **Login:** phone + PIN with a custom keypad; Face ID unlock after the first login; lockout after 3 wrong PINs
- [ ] **Home:** USD and KHR accounts, hide/show balance (saved in `AppSettings`), pull-to-refresh, 60 s cache
- [ ] **Transactions:** paginated list → detail by id (placeholder + cancel + stale-response guard), search with debounce
- [ ] **Transfer:** multi-step flow, idempotency key, PIN confirm, receipt; invalidates balances
- [ ] **KHQR:** scan with the camera, parse, validate CRC, confirm; "My QR" screen
- [ ] **Settings:** in-app English/Khmer switch; logout swaps the root and wipes data
- [ ] **Deep links:** `mybank://transactions/{id}` opens the detail screen

## Security

- [ ] app-switcher privacy cover
- [ ] third-party keyboards blocked
- [ ] ephemeral `URLSession`
- [ ] pinning in Prod only
- [ ] no PII in logs (`Redact`)
- [ ] auto-logout after 5 minutes in the background
- [ ] Keychain cleared on first launch after a reinstall

## Engineering

- [ ] Dev and Prod schemes with `.xcconfig` files, installable side by side
- [ ] Dev-only debug menu (shake)
- [ ] unit tests: mapping, formatting, repository dedupe, token refresh, every ViewModel
- [ ] SwiftLint + swift-format
- [ ] CI: GitHub Actions on a macOS runner (`xcodebuild test`)
- [ ] TestFlight build
- [ ] README with screenshots, an architecture diagram and "what I'd do next"

---

## Alternatives and trade-offs (mock backend)

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| JSON fixtures + mock API in the Dev scheme | no server, instant, perfect for tests | no real HTTP behaviour (latency, errors) unless you add it | first version, unit tests |
| `URLProtocol` stub (like this guide's `FakeServer`) | exercises the real `URLSession` path | test-only code to maintain | testing the network layer |
| Tiny Node/Fastify server | real HTTP, you already know JS | another project to run | demoing the app end to end |
| Mockoon / Postman mock servers / WireMock | GUI or config-driven mocks, shareable with QA | extra tool | team or QA environments |

---

[← Index](../README.md) · [← Interview prep](12-interview-prep.md)
