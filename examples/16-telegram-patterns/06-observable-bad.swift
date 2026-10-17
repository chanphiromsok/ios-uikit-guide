// ❌ BAD: a naive observable: re-renders for values that didn't change, and calls observers while
//         holding its lock (an observer that reads `value` inside its callback would deadlock)
// Run: swift examples/16-telegram-patterns/06-observable-bad.swift
import Foundation

final class NaiveObservable<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Value
    private var observers: [@Sendable (Value) -> Void] = []

    init(_ value: Value) { current = value }

    func observe(_ observer: @escaping @Sendable (Value) -> Void) {
        lock.lock(); observers.append(observer); lock.unlock()       // ❌ no way to stop observing
    }

    func set(_ newValue: Value) {
        lock.lock()
        current = newValue
        observers.forEach { $0(newValue) }                          // ❌ every value, and inside the lock
        lock.unlock()
    }
}

let balance = NaiveObservable("$1,250.50")
balance.observe { value in print("render balance \(value)") }

// The balance socket pushes the same value again and again
for value in ["$1,250.50", "$1,250.50", "$1,250.50", "$1,300.00"] {
    balance.set(value)
}
print("→ 4 renders for 1 real change ❌")
