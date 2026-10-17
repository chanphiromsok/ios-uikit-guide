// ✅ GOOD: an actor lets only one caller touch its state at a time (and the old GCD way: a serial queue)
// Run: swift examples/03-concurrency/04-shared-state-good.swift
import Foundation

actor BalanceCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

let counter = BalanceCounter()
await withTaskGroup(of: Void.self) { group in
    for _ in 0..<10_000 {
        group.addTask { await counter.increment() }
    }
}
print("actor: expected 10000, got \(await counter.value)")

// Before actors (and in older codebases): protect state with a private SERIAL DispatchQueue
final class LegacyCounter: @unchecked Sendable {      // @unchecked = "trust me, I made it safe myself"
    private var value = 0
    private let queue = DispatchQueue(label: "com.mybank.counter")   // serial: one job at a time

    func increment() { queue.sync { value += 1 } }
    var current: Int { queue.sync { value } }
}

let legacy = LegacyCounter()
DispatchQueue.concurrentPerform(iterations: 10_000) { _ in legacy.increment() }
print("serial queue: expected 10000, got \(legacy.current)")
