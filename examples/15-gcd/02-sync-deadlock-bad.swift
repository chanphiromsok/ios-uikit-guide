//! expect: crash
// ❌ BAD: calling queue.sync while already running on that same serial queue → it waits for itself forever
// Run: swift examples/15-gcd/02-sync-deadlock-bad.swift
import Foundation

final class BalanceCache: @unchecked Sendable {                 // state protected by a serial queue
    private let queue = DispatchQueue(label: "com.mybank.balance-cache")
    private var balances: [String: String] = [:]

    func balance(for account: String) -> String? {
        queue.sync { balances[account] }
    }

    func update(_ account: String, to value: String) {
        queue.sync {
            balances[account] = value
            print("saved \(account), reading it back…")
            print("value:", balance(for: account) ?? "nil")   // ❌ balance(for:) calls queue.sync AGAIN
        }
    }
}

BalanceCache().update("000123456", to: "$1,250.50")
print("never printed")
