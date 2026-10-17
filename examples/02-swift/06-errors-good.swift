// ✅ GOOD: specific errors, handled with do/catch, turned into a message the user understands
// Run: swift examples/02-swift/06-errors-good.swift
import Foundation

enum TransferError: Error, CustomStringConvertible {
    case insufficientFunds(available: Decimal)
    case dailyLimitReached

    var description: String {
        switch self {
        case .insufficientFunds(let available): return "Not enough money. Available: $\(available)"
        case .dailyLimitReached:                return "Daily limit reached. Try again tomorrow."
        }
    }
}

// throws(TransferError) = typed throws (Swift 6): callers know exactly which errors can happen
func sendTransfer(amount: Decimal, balance: Decimal) throws(TransferError) -> String {
    guard amount <= balance else { throw .insufficientFunds(available: balance) }
    return "RCPT-001"
}

for amount: Decimal in [50, 500] {
    do {
        let receipt = try sendTransfer(amount: amount, balance: 120)
        print("✅ sent $\(amount), receipt \(receipt)")
    } catch {
        print("⚠️ $\(amount): \(error)")       // `error` is a TransferError here
    }
}
