// ✅ GOOD (modern): wrap the old GCD API once, then write top-to-bottom async/await code
// Run: swift examples/03-concurrency/02-async-await-good.swift
import Foundation

enum BalanceError: Error { case offline }

// The old completion-handler API you inherited (same as 01-completion-handler-good.swift)
func fetchBalanceLegacy(failing: Bool,
                        completion: @escaping @Sendable (Result<String, BalanceError>) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
        let result: Result<String, BalanceError> = failing ? .failure(.offline) : .success("$1,250.50")
        DispatchQueue.main.async { completion(result) }
    }
}

// Bridge: completion handler → async/await
func fetchBalance(failing: Bool) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        fetchBalanceLegacy(failing: failing) { result in
            continuation.resume(with: result)         // resume EXACTLY once
        }
    }
}

// New code reads like normal synchronous code: no nesting, no manual thread hops.
// @MainActor = the compiler guarantees this runs on the main thread, so UI updates here are safe.
@MainActor
func loadHomeScreen() async {
    do {
        let balance = try await fetchBalance(failing: false)
        print("✅ show \(balance)")
        _ = try await fetchBalance(failing: true)
    } catch {
        print("⚠️ show error '\(error)'")
    }
}

await loadHomeScreen()
