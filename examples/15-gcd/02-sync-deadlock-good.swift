// ✅ GOOD: public methods hop onto the queue ONCE; private helpers assume they're already on it (and check it)
// Run: swift examples/15-gcd/02-sync-deadlock-good.swift
import Foundation

final class BalanceCache: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.mybank.balance-cache")
    private var balances: [String: String] = [:]

    func balance(for account: String) -> String? {
        queue.sync { storedBalance(for: account) }
    }

    func update(_ account: String, to value: String) {
        queue.sync {
            balances[account] = value
            print("saved \(account), reading it back…")
            print("value:", storedBalance(for: account) ?? "nil")   // ✅ no second sync
        }
    }

    /// Must only be called while already on `queue`.
    private func storedBalance(for account: String) -> String? {
        dispatchPrecondition(condition: .onQueue(queue))            // stops in debug if called from elsewhere
        return balances[account]
    }
}

let cache = BalanceCache()
cache.update("000123456", to: "$1,250.50")
print("from outside:", cache.balance(for: "000123456") ?? "nil")
// Even simpler in new code: make BalanceCache an `actor` (see docs/03-concurrency.md), and this bug can't happen.
