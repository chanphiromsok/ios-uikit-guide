# 07 · Dev and Prod environments

[← Index](../README.md) · [← Architecture](06-architecture.md) · [Next: Local storage →](08-local-storage.md)

Use **Build Configurations + `.xcconfig` files + Schemes**. One app target with several configurations is simpler than one target per environment.

> **Debug ≠ Dev.** `Debug` / `Release` are about compiler optimization. **Dev / Staging / Prod** are about which server and bundle ID you use. You need Release builds of Staging (for TestFlight testers) and Debug builds pointing at Prod (to reproduce a bug), so keep the two ideas separate.

---

## ❌ Bad: switching by editing code

<!-- example: examples/07-environments/01-environment-bad.swift -->
```swift
// ❌ BAD: switching environments by editing code, and a secret inside the app
// Run: swift examples/07-environments/01-environment-bad.swift

// let baseURL = "https://api.mybank.com"      // PROD
let baseURL = "https://api-dev.mybank.com"     // DEV  ← someone forgets to switch back before release
let apiKey = "sk_live_9f8e7d6c5b4a"            // ❌ anyone can extract strings from the app binary

print("Building for the App Store with base URL:", baseURL)
print("→ customers' app talks to the DEV server, and the 'secret' key ships to every phone")
```

**Output**

```text
Building for the App Store with base URL: https://api-dev.mybank.com
→ customers' app talks to the DEV server, and the 'secret' key ships to every phone
```
<!-- /example -->

## ✅ Good: xcconfig → Info.plist → one validated `AppEnvironment`

<!-- example: examples/07-environments/01-environment-good.swift -->
```swift
// ✅ GOOD: values come from .xcconfig → Info.plist → one validated AppEnvironment (and it's testable)
// Run: swift examples/07-environments/01-environment-good.swift
import Foundation

struct AppEnvironment: Sendable {
    enum Name: String, Sendable { case dev = "Dev", staging = "Staging", prod = "Prod" }

    enum ConfigError: Error {
        case missing(String)
        case invalid(key: String, value: String)
    }

    let name: Name
    let apiBaseURL: URL

    /// In the app: `try AppEnvironment(info: Bundle.main.infoDictionary ?? [:])`
    init(info: [String: Any]) throws {
        guard let rawName = info["AppEnvironment"] as? String else { throw ConfigError.missing("AppEnvironment") }
        guard let name = Name(rawValue: rawName) else { throw ConfigError.invalid(key: "AppEnvironment", value: rawName) }
        guard let rawURL = info["APIBaseURL"] as? String else { throw ConfigError.missing("APIBaseURL") }
        guard let url = URL(string: rawURL), url.scheme == "https", url.host != nil else {
            throw ConfigError.invalid(key: "APIBaseURL", value: rawURL)
        }
        self.name = name
        self.apiBaseURL = url
    }
}

// What Info.plist contains after Xcode fills in $(API_BASE_URL) from Dev.xcconfig / Prod.xcconfig:
let builds: [(scheme: String, info: [String: Any])] = [
    ("MyBank Dev", ["AppEnvironment": "Dev", "APIBaseURL": "https://api-dev.mybank.com"]),
    ("MyBank Prod", ["AppEnvironment": "Prod", "APIBaseURL": "https://api.mybank.com"]),
    // xcconfig treats // as a comment, so "https://api.mybank.com" becomes "https:" unless you write https:/$()/
    ("Broken config", ["AppEnvironment": "Prod", "APIBaseURL": "https:"]),
]

for build in builds {
    do {
        let environment = try AppEnvironment(info: build.info)
        print("✅ \(build.scheme): \(environment.name) → \(environment.apiBaseURL)")
    } catch {
        print("❌ \(build.scheme): \(error) → fail fast at launch, not after release")
    }
}
```

**Output**

```text
✅ MyBank Dev: dev → https://api-dev.mybank.com
✅ MyBank Prod: prod → https://api.mybank.com
❌ Broken config: invalid(key: "APIBaseURL", value: "https:") → fail fast at launch, not after release
```
<!-- /example -->

---

## Set it up in Xcode

**1. Create configurations.** Project → Info → Configurations: `Debug-Dev`, `Debug-Prod`, `Release-Staging`, `Release-Prod`.

**2. Add an `.xcconfig` per environment** (copy from [`examples/07-environments/Config`](../examples/07-environments/Config)) and assign each configuration its file:

<!-- snippet: examples/07-environments/Config/Shared.xcconfig -->
```text
// Shared.xcconfig: settings every environment uses
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1
IPHONEOS_DEPLOYMENT_TARGET = 16.0
```
<!-- /snippet -->

<!-- snippet: examples/07-environments/Config/Dev.xcconfig -->
```text
// Dev.xcconfig
#include "Shared.xcconfig"
#include? "Secrets.xcconfig"                       // optional, git-ignored, created by CI

APP_ENVIRONMENT = Dev
API_BASE_URL = https:/$()/api-dev.mybank.com       // "//" starts a comment in xcconfig, hence $()
PRODUCT_BUNDLE_IDENTIFIER = com.mybank.app.dev     // different ID → Dev and Prod install side by side
APP_DISPLAY_NAME = MyBank Dev
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Dev
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEV
```
<!-- /snippet -->

<!-- snippet: examples/07-environments/Config/Prod.xcconfig -->
```text
// Prod.xcconfig
#include "Shared.xcconfig"
#include? "Secrets.xcconfig"

APP_ENVIRONMENT = Prod
API_BASE_URL = https:/$()/api.mybank.com
PRODUCT_BUNDLE_IDENTIFIER = com.mybank.app
APP_DISPLAY_NAME = MyBank
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
```
<!-- /snippet -->

**3. Expose the values in `Info.plist`:**

<!-- snippet: examples/07-environments/Config/Info-additions.plist -->
```xml
<!-- Add these keys to your app's Info.plist -->
<key>AppEnvironment</key>
<string>$(APP_ENVIRONMENT)</string>
<key>APIBaseURL</key>
<string>$(API_BASE_URL)</string>
<key>CFBundleDisplayName</key>
<string>$(APP_DISPLAY_NAME)</string>
```
<!-- /snippet -->

**4. Read them once at launch** with `try AppEnvironment(info: Bundle.main.infoDictionary ?? [:])`, shown in the ✅ example above.

**5. Create Schemes** "MyBank Dev" and "MyBank Prod" (Product → Scheme → Manage Schemes), each pointing at its configurations. CI builds with:

```bash
xcodebuild -scheme "MyBank Prod" -configuration Release-Prod archive
```

**Notes**
- **The `//` trap:** `//` starts a comment in xcconfig. Write URLs as `https:/$()/host`. The ✅ example shows how a broken URL is caught at launch.
- **Secrets:**
  - Keep `Secrets.xcconfig` out of git (add it to `.gitignore`) and have CI create it.
  - **Anything shipped in the app can be extracted.** Real secrets stay on the server.
- **Dev-only code:** `#if DEV … #endif` works because `Dev.xcconfig` sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEV`.
- **Side by side:** a different `PRODUCT_BUNDLE_IDENTIFIER` and icon per environment lets testers install Dev and Prod together.
- **Per-environment files** such as Firebase's `GoogleService-Info.plist` get copied by a build-phase script.

**Practice**

- [ ] Add a `Staging.xcconfig` and a "Staging" case to `AppEnvironment.Name`.
- [ ] Break the URL on purpose (`https://…` without `$()`) and watch `AppEnvironment` fail at launch.

---

## Alternatives and trade-offs

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| **Configurations + `.xcconfig` + schemes** (this guide) | one target, settings in reviewable text files | xcconfig quirks (`//` comments) | default |
| Multiple targets (MyBank-Dev, MyBank-Prod) | different capabilities and entitlements per app | file membership drift, duplicated settings | the apps really differ (e.g. a white-label bank) |
| Runtime environment switcher (debug menu) | QA can switch servers without reinstalling | must be compiled out of Release (`#if DEV`) | internal QA builds |
| Remote config / feature flags (e.g. Firebase Remote Config) | change behaviour without a release | **never for secrets**; needs a fallback when offline | feature flags, kill switches |
| Tuist / XcodeGen generated settings | environments defined in code/YAML | extra tool | already using them for modules |
| Secrets obfuscation (e.g. Arkana) | hides strings from casual `strings` dumps | still extractable by a determined attacker | low-value keys only; real secrets stay on the server |

---

[← Index](../README.md) · [← Architecture](06-architecture.md) · [Next: Local storage →](08-local-storage.md)
