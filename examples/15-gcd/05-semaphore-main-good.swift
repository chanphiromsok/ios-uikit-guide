// ✅ GOOD: never block the main thread: react when the result arrives (or bridge to async/await, see docs/03)
// Run: swift examples/15-gcd/05-semaphore-main-good.swift
import Foundation

func fetchBalance(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
        DispatchQueue.main.async { completion("$1,250.50") }
    }
}

print("Home screen shows a spinner and keeps responding…")
fetchBalance { balance in
    print("✅ got \(balance) → hide spinner, show balance")
    exit(0)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    print("   (the user scrolls: the UI still responds while we wait)")
}
dispatchMain()
