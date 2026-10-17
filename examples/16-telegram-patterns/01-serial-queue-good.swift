// ✅ IDEA FROM TELEGRAM (SwiftSignalKit `Queue`): a serial queue that knows whether you're already on it.
// Nested sync calls run inline instead of deadlocking (compare examples/15-gcd/02-sync-deadlock-bad.swift).
// Written from scratch for this guide; not Telegram's code.
// Run: swift examples/16-telegram-patterns/01-serial-queue-good.swift
import Foundation

final class SerialQueue: @unchecked Sendable {
    private let queue: DispatchQueue
    private let key = DispatchSpecificKey<Bool>()        // a per-queue tag, readable from inside the queue

    init(label: String, qos: DispatchQoS = .default) {
        queue = DispatchQueue(label: label, qos: qos)
        queue.setSpecific(key: key, value: true)
    }

    /// true while running on this queue
    var isCurrent: Bool { DispatchQueue.getSpecific(key: key) == true }

    /// Runs now if we're already on this queue; otherwise hops onto it and waits.
    func sync<T>(_ work: () throws -> T) rethrows -> T {
        isCurrent ? try work() : try queue.sync(execute: work)
    }

    /// Runs now if already on this queue (keeps ordering with the surrounding code); otherwise dispatches.
    func asyncOrInline(_ work: @escaping @Sendable () -> Void) {
        if isCurrent { work() } else { queue.async(execute: work) }
    }
}

final class BalanceCache: @unchecked Sendable {
    private let queue = SerialQueue(label: "com.mybank.balance-cache")
    private var balances: [String: String] = [:]

    func balance(for account: String) -> String? {
        queue.sync { balances[account] }
    }

    func update(_ account: String, to value: String) {
        queue.sync {
            balances[account] = value
            print("saved \(account), reading it back… (on the queue? \(queue.isCurrent))")
            print("value:", balance(for: account) ?? "nil")   // nested sync → runs inline, no deadlock
        }
    }
}

let cache = BalanceCache()
cache.update("000123456", to: "$1,250.50")
print("from outside:", cache.balance(for: "000123456") ?? "nil")
