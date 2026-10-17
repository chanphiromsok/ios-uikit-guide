// ✅ GOOD: reader-writer pattern: reads run together with sync, writes run ALONE with a barrier
// Run: swift examples/15-gcd/03-concurrent-queue-good.swift
import Foundation

final class TransactionCounter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.mybank.counter", attributes: .concurrent)  // must be YOUR queue
    private var count = 0

    func increment() { queue.async(flags: .barrier) { self.count += 1 } }   // ✅ waits for readers, runs alone
    var value: Int { queue.sync { count } }                                 // many readers can run at once
}

let counter = TransactionCounter()
DispatchQueue.concurrentPerform(iterations: 10_000) { _ in counter.increment() }
print("expected 10000, got \(counter.value)")
// ⚠️ .barrier does nothing special on DispatchQueue.global(): it only works on a custom concurrent queue.
