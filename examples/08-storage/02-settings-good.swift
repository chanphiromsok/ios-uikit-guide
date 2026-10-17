// ✅ GOOD: one typed settings wrapper → keys live in one place, values have real types, easy to reset on logout
// Run: swift examples/08-storage/02-settings-good.swift
import Foundation

struct AppSettings {
    enum Language: String { case english = "en", khmer = "km" }

    private enum Key {
        static let isBalanceHidden = "settings.isBalanceHidden"
        static let language = "settings.language"
        static let all = [isBalanceHidden, language]
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isBalanceHidden: Bool {
        get { defaults.bool(forKey: Key.isBalanceHidden) }
        nonmutating set { defaults.set(newValue, forKey: Key.isBalanceHidden) }
    }

    var language: Language {
        get { defaults.string(forKey: Key.language).flatMap(Language.init(rawValue:)) ?? .english }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    func reset() { Key.all.forEach(defaults.removeObject(forKey:)) }   // call on logout
}

// A separate suite keeps this demo (and your unit tests) away from real settings
guard let demoDefaults = UserDefaults(suiteName: "guide-demo-settings-good") else { fatalError("no defaults") }
let settings = AppSettings(defaults: demoDefaults)

settings.isBalanceHidden = true
settings.language = .khmer
print("balance hidden?", settings.isBalanceHidden)
print("language:", settings.language)

settings.reset()
print("after logout → balance hidden?", settings.isBalanceHidden, "| language:", settings.language)
demoDefaults.removePersistentDomain(forName: "guide-demo-settings-good")
