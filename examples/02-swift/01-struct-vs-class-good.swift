// ✅ GOOD: a struct for models → every assignment is an independent copy
// Run: swift examples/02-swift/01-struct-vs-class-good.swift
import Foundation

struct TransferDraft {
    var amount: Decimal
    var toAccount: String
}

let original = TransferDraft(amount: 100, toAccount: "000123456")
var edited = original              // a COPY
edited.amount = 5_000

print("original amount:", original.amount)   // 100 ✅ untouched
print("edited amount:  ", edited.amount)     // 5000
