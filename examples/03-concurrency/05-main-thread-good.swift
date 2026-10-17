// ✅ GOOD: do the slow work in the background, then update the UI on the main actor
// Run: swift examples/03-concurrency/05-main-thread-good.swift
import Foundation

@MainActor
final class Label {
    var text = "" { didSet { print("label.text = \(text)") } }
}

func fetchBalance() async throws -> String {
    try await Task.sleep(for: .milliseconds(200))     // network work happens off the main thread
    return "$1,250.50"
}

@MainActor
final class HomeViewController {                      // in UIKit, UIViewController is already @MainActor
    let balanceLabel = Label()

    func viewDidLoad() async {
        balanceLabel.text = "Loading…"
        do {
            let balance = try await fetchBalance()
            balanceLabel.text = balance               // ✅ back on the main actor automatically
        } catch {
            balanceLabel.text = "Unavailable"
        }
    }
}

await HomeViewController().viewDidLoad()

// GCD-style equivalent you'll see in older code:
// DispatchQueue.global().async {
//     let value = slowWork()
//     DispatchQueue.main.async { label.text = value }
// }
