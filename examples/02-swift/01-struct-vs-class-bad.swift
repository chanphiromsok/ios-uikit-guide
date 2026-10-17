// ❌ BAD: a class for a simple model → shared, surprising changes
// Run: swift examples/02-swift/01-struct-vs-class-bad.swift
import Foundation

final class TransferDraft {
    var amount: Decimal
    var toAccount: String

    init(amount: Decimal, toAccount: String) {
        self.amount = amount
        self.toAccount = toAccount
    }
}

let original = TransferDraft(amount: 100, toAccount: "000123456")
let edited = original              // NOT a copy: both names point to the SAME object
edited.amount = 5_000              // the user edits the draft on the next screen…

print("original amount:", original.amount)   // 5000 😱 the "original" changed too
print("edited amount:  ", edited.amount)
