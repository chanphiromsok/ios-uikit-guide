//! expect: crash
// ❌ BAD: resuming a continuation twice → crash (forgetting to resume = the caller waits forever)
// Run: swift examples/03-concurrency/02-continuation-bad.swift
import Foundation

func fetchBalanceLegacy(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { completion("$1,250.50") }
}

func fetchBalance() async -> String {
    await withCheckedContinuation { continuation in
        fetchBalanceLegacy { balance in
            continuation.resume(returning: balance)   // 2nd resume → 💥
        }
        continuation.resume(returning: "$0.00")       // "default value" added by mistake → 1st resume
    }
}

let balance = await fetchBalance()
print("balance:", balance)
try await Task.sleep(for: .seconds(1))                // wait for the legacy callback to fire
