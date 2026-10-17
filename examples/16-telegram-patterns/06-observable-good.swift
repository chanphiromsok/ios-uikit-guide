// ✅ IDEAS FROM TELEGRAM (`ValuePromise` + `ValuePipe`): ignore repeated values, replay the current value
//    to new observers, copy observers under the lock but CALL them outside it, and stop observing when
//    a token is released. Written from scratch.
// Run: swift examples/16-telegram-patterns/06-observable-good.swift
import Foundation

final class ObservationToken: Sendable {
    private let onRelease: @Sendable () -> Void
    init(_ onRelease: @escaping @Sendable () -> Void) { self.onRelease = onRelease }
    deinit { onRelease() }                                        // releasing the token stops the observation
}

final class ObservableValue<Value: Equatable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Value
    private var observers: [UUID: @Sendable (Value) -> Void] = [:]

    init(_ value: Value) { current = value }

    var value: Value { lock.lock(); defer { lock.unlock() }; return current }

    func set(_ newValue: Value) {
        lock.lock()
        guard newValue != current else { lock.unlock(); return }     // ✅ nothing changed → nobody is called
        current = newValue
        let toNotify = Array(observers.values)                       // ✅ copy under the lock…
        lock.unlock()
        toNotify.forEach { $0(newValue) }                            // …call outside it
    }

    func observe(_ observer: @escaping @Sendable (Value) -> Void) -> ObservationToken {
        let id = UUID()
        lock.lock()
        observers[id] = observer
        let initial = current
        lock.unlock()
        observer(initial)                                            // ✅ new observers get the current value
        return ObservationToken { [weak self] in self?.removeObserver(id) }
    }

    private func removeObserver(_ id: UUID) {
        lock.lock(); observers[id] = nil; lock.unlock()
    }
}

let balance = ObservableValue("$1,250.50")
var token: ObservationToken? = balance.observe { value in
    print("render balance \(value) (reading .value inside the callback is safe: \(balance.value))")
}

for value in ["$1,250.50", "$1,250.50", "$1,250.50", "$1,300.00"] {
    balance.set(value)
}
print("→ 2 renders: the initial value + 1 real change ✅")

token = nil                                                          // the screen went away
balance.set("$1,400.00")
print("after releasing the token: no more renders ✅")
_ = token
