# 11 · Devtools

[← Index](../README.md) · [← Performance and rendering](10-performance-and-rendering.md) · [Next: Interview prep →](12-interview-prep.md)

## Chrome / React DevTools → iOS

| What you use today | iOS equivalent |
|---|---|
| Elements tab | **Debug View Hierarchy** (3D view of the UI) |
| Console / `console.log` | Xcode console + `os.Logger`; Console.app for device logs |
| Sources tab breakpoints | **LLDB** breakpoints |
| Network tab | **Proxyman** / Charles, Instruments' Network template, **Pulse** (in-app) |
| Performance tab | **Instruments**: Time Profiler, Animation Hitches |
| Memory tab | **Memory Graph Debugger**, Instruments Leaks / Allocations |
| Application tab | `xcrun simctl get_app_container` + a SQLite viewer |
| Device toolbar | different Simulators + **Environment Overrides** |
| Network throttling | **Network Link Conditioner** |
| Lighthouse accessibility audit | **Accessibility Inspector** |
| Fast Refresh | `#Preview`, InjectionIII |
| RN dev menu | your own Dev-only debug menu |
| Sentry / Crashlytics | the same tools, plus the Xcode Organizer and MetricKit |

---

## LLDB cheat sheet

```
(lldb) po viewModel.state             // print an object (like console.log)
(lldb) v self.amountLabel.text        // read a variable quickly (no code runs)
(lldb) e amountLabel.textColor = .red // change a value while paused
(lldb) e CATransaction.flush()        // redraw the screen without continuing
(lldb) bt                             // backtrace: how did we get here?
(lldb) c                              // continue
```

- **Log without rebuilding:** breakpoint → Edit → Action "Log Message" + "Automatically continue".
- **Conditional breakpoints:** stop only when `account.id == "123"`.
- **Exception Breakpoint:** stops on the line that crashes, not in `main`.
- **Symbolic breakpoint `UIViewAlertForUnsatisfiableConstraints`:** stops on Auto Layout conflicts.

> 🐧 You can practise LLDB on Linux: `swiftc -g examples/02-swift/05-retain-cycle-bad.swift -o leak && lldb ./leak`.

## Logging

```swift
// ❌ BAD: print() has no levels or filtering, ends up in production, and leaks data
print("token: \(token)")

// ✅ GOOD: levels, categories, filtering in Xcode/Console.app, private by default
import OSLog
extension Logger {
    static let network = Logger(subsystem: "com.mybank.app", category: "network")
}
Logger.network.debug("GET \(url, privacy: .public) → \(statusCode)")
```

## Memory Graph: find retain cycles

1. Open a screen, go back. Repeat 5 times.
2. Click **Debug Memory Graph** in the debug bar.
3. If 5 instances of the screen are still alive, there's a cycle. Purple `!` icons mark leaks.
4. Enable *Scheme → Diagnostics → Malloc Stack Logging* to see where each object was created.

Practise with [`02-swift/05-retain-cycle-bad.swift`](../examples/02-swift/05-retain-cycle-bad.swift) and [`05-uikit/01-delegate-bad.swift`](../examples/05-uikit/01-delegate-bad.swift).

## Instruments (Product → Profile, ⌘I; on a real device)

| Instrument | Use it for |
|---|---|
| Time Profiler | "what is slow?" |
| Animation Hitches | laggy scrolling |
| Allocations / Leaks | memory growth, leaks |
| App Launch | slow startup |
| Network | HTTP traffic from `URLSession` |
| Swift Concurrency | tasks and actors blocking each other |

## Simulator and command-line tricks

```bash
open "$(xcrun simctl get_app_container booted com.mybank.app.dev data)"   # app files, UserDefaults plist
xcrun simctl openurl booted "mybank://transactions/T3"                    # test deep links (see 05 · 5.8)
xcrun simctl push booted com.mybank.app.dev payload.apns                  # fake a push notification
xcrun simctl io booted recordVideo demo.mov                                # record the screen
xcrun simctl status_bar booted override --time 9:41                        # clean screenshots
```

- **Network Link Conditioner:**
  - On a Mac: "Additional Tools for Xcode".
  - On an iPhone: Settings → Developer.
  - Test "3G" and "Very Bad Network": users in the provinces will have connections like these.
- **Environment Overrides** (debug bar): dark mode, Dynamic Type sizes, accessibility.

## Scheme diagnostics and launch arguments

| Setting | Catches |
|---|---|
| Main Thread Checker (on by default) | UI updated from a background thread ([03 · 3.5](03-concurrency.md#35-ui-updates-on-the-main-thread)) |
| Thread Sanitizer | data races ([03 · 3.4](03-concurrency.md#34-shared-mutable-state)) |
| Address Sanitizer | memory corruption |
| App Language → Double-Length Pseudolanguage | text that truncates when translated |
| Argument `-AppleLanguages (km)` | launch the app in **Khmer** |

## Dev-only debug menu

```swift
// ❌ BAD: a hidden switch that also exists in the App Store build. Pentesters will find it.
if UserDefaults.standard.bool(forKey: "showDebugMenu") { showDebugMenu() }

// ✅ GOOD: compiled out of Release builds entirely (DEV is set in Dev.xcconfig, see 07)
#if DEV
final class DebugWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }          // ⌃⌘Z in the Simulator
        rootViewController?.topMostPresented.present(DebugMenuViewController(), animated: true)
    }
}
#endif
```

(`topMostPresented` is from [05 · 5.7](05-uikit.md#57-presenting-from-the-top).)

Useful menu items:
- Switch environment
- Network log (Pulse)
- Clear Keychain and caches
- Force token expiry
- Feature flags
- Build number and commit

## Crashes in production

- **Xcode Organizer** → Crashes, Hangs, Energy (from TestFlight and App Store users).
- **Firebase Crashlytics or Sentry.**
- **Upload dSYMs on every release**, or crash reports are unreadable.
- **MetricKit** for on-device performance and diagnostic reports.

---

## Alternatives and trade-offs

| Need | Option | ✅ Strengths | ⚠️ Trade-offs |
|---|---|---|---|
| Network inspection | Proxyman | native macOS app, easy certificate setup | paid for full features; blocked by pinning |
| Network inspection | Charles | cross-platform, long history | paid; dated UI; blocked by pinning |
| Network inspection | mitmproxy | free, scriptable | command line; blocked by pinning |
| Network inspection | Pulse (in-app) | logs on the device; QA can share them; works with pinning | must be excluded from Release |
| Network inspection | Instruments Network/HTTP Traffic | built-in, no proxy | needs a Mac and Instruments |
| UI inspection | Xcode View Debugger | free, built-in | slower on big hierarchies |
| UI inspection | Reveal (paid) / Lookin (free) | richer live editing | extra app |
| UI inspection | FLEX (in-app) | inspect views, network, files on device | Dev builds only (security) |
| Crash reporting | Firebase Crashlytics | free, popular | Google SDK; data leaves your infrastructure |
| Crash reporting | Sentry | performance traces, self-hosting option (data residency) | paid tiers |
| Crash reporting | Xcode Organizer | built-in, no SDK | delayed, TestFlight/App Store only |
| Lint / format | SwiftLint | many rules, CI-friendly | config to maintain |
| Lint / format | swift-format (Apple) / SwiftFormat | automatic formatting | pick one style for the team |
| CI/CD | Xcode Cloud | Apple-hosted, simple signing, free hours with the developer program | less flexible scripting |
| CI/CD | GitHub Actions (macOS runners) | flexible, huge ecosystem | macOS minutes cost more |
| CI/CD | Bitrise / Codemagic | mobile-focused steps | paid plans |
| CI/CD | Self-hosted Mac mini + Fastlane | full control, on-premise (some banks require it) | you maintain the machine |

---

[← Index](../README.md) · [← Performance and rendering](10-performance-and-rendering.md) · [Next: Interview prep →](12-interview-prep.md)
