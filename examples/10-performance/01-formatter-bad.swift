//! output: varies
// ❌ BAD: creating an expensive formatter for every row (often inside cellForRowAt)
// Run: swift examples/10-performance/01-formatter-bad.swift
import Foundation

let amounts = (1...20_000).map { Decimal($0) / 100 }

let start = ContinuousClock.now
var texts: [String] = []
for amount in amounts {
    let formatter = NumberFormatter()                 // ❌ a new formatter per row
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.locale = Locale(identifier: "en_US")
    texts.append(formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "")
}
let elapsed = ContinuousClock.now - start

print("first row:", texts[0], "| last row:", texts[texts.count - 1])
print("20,000 rows took \(elapsed.formatted(.units(allowed: [.milliseconds])))")
