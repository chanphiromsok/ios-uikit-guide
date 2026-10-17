//! expect: compile-error
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
