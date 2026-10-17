//! output: varies
// ❌ BAD: a CONCURRENT queue protects nothing by itself: writes overlap and updates are lost
// Run: swift examples/15-gcd/03-concurrent-queue-bad.swift
import Foundation

final class TransactionCounter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.mybank.counter", attributes: .concurrent)
    private var count = 0

    func increment() { queue.async { self.count += 1 } }          // ❌ many writes at the same time
    var value: Int { queue.sync { count } }
}

let counter = TransactionCounter()
DispatchQueue.concurrentPerform(iterations: 10_000) { _ in counter.increment() }
Thread.sleep(forTimeInterval: 0.5)                                // let the writes finish
print("expected 10000, got \(counter.value)")
