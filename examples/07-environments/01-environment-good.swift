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
