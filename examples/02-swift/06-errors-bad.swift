// ❌ BAD: try? swallows the error → the user sees "nothing happened" and support can't help
// Run: swift examples/02-swift/06-errors-bad.swift
import Foundation

enum TransferError: Error {
    case insufficientFunds
    case dailyLimitReached
}

func sendTransfer(amount: Decimal, balance: Decimal) throws -> String {
    guard amount <= balance else { throw TransferError.insufficientFunds }
    return "RCPT-001"
}

let receipt = try? sendTransfer(amount: 500, balance: 120)
print("receipt:", receipt ?? "nil")            // nil… but WHY? The reason is lost.
