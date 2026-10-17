// ✅ IDEA FROM TELEGRAM (SwiftSignalKit `Atomic<T>`): wrap a value and its lock together, so it can't be
// touched without the lock. Written from scratch: NSLock, `defer` unlock, `inout` modify.
// Run: swift examples/16-telegram-patterns/02-atomic-good.swift
import Foundation

final class Atomic<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    /// Read (or compute something from) the value while holding the lock.
    func with<Result>(_ body: (Value) throws -> Result) rethrows -> Result {
        lock.lock(); defer { lock.unlock() }
        return try body(value)
    }

    /// Change the value in place while holding the lock.
    @discardableResult
    func modify<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock(); defer { lock.unlock() }
        return try body(&value)
    }

    /// Replace the value and get the old one back in one step (handy for "take everything and reset").
    func swap(_ newValue: Value) -> Value {
        modify { current in
            let old = current
            current = newValue
            return old
        }
    }
}

// 1. A counter updated from many threads at once
let taps = Atomic(0)
DispatchQueue.concurrentPerform(iterations: 10_000) { _ in taps.modify { $0 += 1 } }
print("taps: expected 10000, got \(taps.with { $0 })")

// 2. Analytics events collected from many threads, then flushed as one batch
let pendingEvents = Atomic<[String]>([])
DispatchQueue.concurrentPerform(iterations: 250) { index in
    pendingEvents.modify { $0.append("screen_view_\(index)") }
}
let batch = pendingEvents.swap([])                  // take all events and empty the buffer atomically
print("uploading \(batch.count) events; left in buffer: \(pendingEvents.with(\.count))")

// ⚠️ The lock is not recursive: calling taps.with { _ in taps.with { … } } would deadlock.
