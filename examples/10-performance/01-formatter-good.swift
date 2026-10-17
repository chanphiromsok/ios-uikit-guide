//! output: varies
// ✅ GOOD: create the formatter once and reuse it (or use FormatStyle, which Foundation caches for you)
// Run: swift examples/10-performance/01-formatter-good.swift
import Foundation

let amounts = (1...20_000).map { Decimal($0) / 100 }

enum Formatters {
    static let usd: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
}

var start = ContinuousClock.now
let shared = amounts.map { Formatters.usd.string(from: NSDecimalNumber(decimal: $0)) ?? "" }
print("shared NumberFormatter: \((ContinuousClock.now - start).formatted(.units(allowed: [.milliseconds])))")

start = ContinuousClock.now
let style = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
let styled = amounts.map { $0.formatted(style) }
print("FormatStyle:            \((ContinuousClock.now - start).formatted(.units(allowed: [.milliseconds])))")

print("same text?", shared == styled ? "yes" : "no", "| first row:", styled[0], "| last row:", styled[styled.count - 1])
