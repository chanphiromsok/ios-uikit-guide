// ✅ IDEA FROM TELEGRAM (`debounceOnMainThread`): keep only the LATEST value and schedule ONE main-queue
//    flush per burst → many changes in the same turn become one UI update. Written from scratch.
// Run: swift examples/16-telegram-patterns/07-coalesce-good.swift
import Foundation

final class MainQueueCoalescer<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: Value?
    private let deliver: @Sendable (Value) -> Void              // called on the main queue

    init(deliver: @escaping @Sendable (Value) -> Void) { self.deliver = deliver }

    func send(_ value: Value) {
        lock.lock()
        let flushAlreadyScheduled = pending != nil
        pending = value                                         // newer value replaces the older one
        lock.unlock()
        if !flushAlreadyScheduled {
            DispatchQueue.main.async { self.flush() }
        }
    }

    private func flush() {
        lock.lock()
        let value = pending
        pending = nil
        lock.unlock()
        if let value { deliver(value) }
    }
}

final class AccountsScreen: @unchecked Sendable {
    private lazy var reloads = MainQueueCoalescer<[String]> { snapshot in
        print("reload list (\(snapshot.count) accounts)")      // ✅ once per burst, with the newest data
    }

    func accountsDidChange(_ snapshot: [String]) { reloads.send(snapshot) }
}

let screen = AccountsScreen()
DispatchQueue.main.async {
    var accounts: [String] = []
    for name in ["Savings USD", "Current USD", "Savings KHR", "Current KHR", "Loan"] {
        accounts.append(name)
        screen.accountsDidChange(accounts)
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    print("→ 1 reload with all 5 accounts ✅")
    exit(0)
}
dispatchMain()
