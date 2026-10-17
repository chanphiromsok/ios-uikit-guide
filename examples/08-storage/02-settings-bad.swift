// ❌ BAD: "stringly-typed" UserDefaults keys scattered around the app → one typo = a silent bug
// Run: swift examples/08-storage/02-settings-bad.swift
import Foundation

guard let defaults = UserDefaults(suiteName: "guide-demo-settings-bad") else { fatalError("no defaults") }

// Settings screen
defaults.set(true, forKey: "isBalanceHidden")

// Home screen, written by another developer
let hidden = defaults.bool(forKey: "isBalancehidden")      // typo: lowercase "h"
print("balance hidden?", hidden, "→ the balance is shown on the home screen 😱")

defaults.removePersistentDomain(forName: "guide-demo-settings-bad")
