// ❌ BAD: every model change schedules its own UI reload → 5 reloads in one run-loop turn
// Run: swift examples/16-telegram-patterns/07-coalesce-bad.swift
import Foundation

final class AccountsScreen: @unchecked Sendable {
    func accountsDidChange(_ snapshot: [String]) {
        DispatchQueue.main.async {
            print("reload list (\(snapshot.count) accounts)")     // ❌ one reload per change
        }
    }
}

let screen = AccountsScreen()
DispatchQueue.main.async {
    // A sync response updates 5 accounts one after another, all in one turn of the main queue
    var accounts: [String] = []
    for name in ["Savings USD", "Current USD", "Savings KHR", "Current KHR", "Loan"] {
        accounts.append(name)
        screen.accountsDidChange(accounts)
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    print("→ 5 reloads; only the last one mattered ❌")
    exit(0)
}
dispatchMain()
