// ✅ GOOD: Decimal for money, created from strings (APIs should send amounts as strings)
// Run: swift examples/02-swift/04-money-good.swift
import Foundation

func money(_ text: String) -> Decimal {
    guard let value = Decimal(string: text) else { preconditionFailure("Invalid amount: \(text)") }
    return value
}

let fee = money("0.1")
let tax = money("0.2")
print("0.1 + 0.2 =", fee + tax)                 // 0.3
print("equals 0.3?", fee + tax == money("0.3")) // true ✅

var balance = Decimal.zero
for _ in 0..<10 { balance += money("0.10") }
print("balance after 10 × $0.10 =", balance)    // 1
print("can pay $1.00?", balance >= 1)           // true ✅
