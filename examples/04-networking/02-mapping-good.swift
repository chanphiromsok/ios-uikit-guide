// ✅ GOOD: DTO (mirrors the API) → Domain (business rules) → ViewData (display-ready strings)
// Run: swift examples/04-networking/02-mapping-good.swift
import Foundation

// ── 1. DTO: exactly what the API sends ─────────────────────────────────────────────
struct TransactionDTO: Decodable, Sendable {
    let id: String
    let amount: String                  // "-4.50": money as a string, never Double
    let currency: String
    let bookedAt: Date
    let merchantName: String?
}

// ── 2. Domain: what the app reasons about ─────────────────────────────────────────
enum Currency: String, Sendable { case usd = "USD", khr = "KHR" }

struct Money: Hashable, Sendable {
    let amount: Decimal
    let currency: Currency

    func displayText(locale: Locale = .current) -> String {
        switch currency {
        case .usd: return amount.formatted(.currency(code: "USD").locale(locale))                      // -$4.50
        case .khr: return amount.formatted(.number.precision(.fractionLength(0)).locale(locale)) + " ៛"  // -50,000 ៛
        }
    }
}

struct Transaction: Sendable {
    let id: String
    let money: Money
    let date: Date
    let merchant: String
}

enum MappingError: Error {
    case invalidAmount(String)
    case unknownCurrency(String)
}

extension Transaction {
    init(dto: TransactionDTO) throws {
        guard let amount = Decimal(string: dto.amount) else { throw MappingError.invalidAmount(dto.amount) }
        guard let currency = Currency(rawValue: dto.currency) else { throw MappingError.unknownCurrency(dto.currency) }
        id = dto.id
        money = Money(amount: amount, currency: currency)
        date = dto.bookedAt
        merchant = dto.merchantName ?? "Unknown merchant"
    }
}

// ── 3. ViewData: only strings and flags; the cell just displays them ──────────────
struct TransactionRowViewData: Hashable, Sendable {
    let id: String
    let title: String
    let amountText: String
    let dateText: String
    let isDebit: Bool

    init(_ transaction: Transaction, locale: Locale = .current) {
        id = transaction.id
        title = transaction.merchant
        amountText = transaction.money.displayText(locale: locale)
        dateText = transaction.date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
        isDebit = transaction.money.amount < 0
    }
}

// ── Demo ───────────────────────────────────────────────────────────────────────────
let json = #"""
[
  {"id":"T1","amount":"-4.50","currency":"USD","booked_at":"2026-10-15T12:00:00Z","merchant_name":"Coffee Shop"},
  {"id":"T2","amount":"-50000","currency":"KHR","booked_at":"2026-10-15T12:00:00Z","merchant_name":"Lucky Market"},
  {"id":"T3","amount":"abc","currency":"USD","booked_at":"2026-10-16T12:00:00Z","merchant_name":null}
]
"""#

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase   // booked_at → bookedAt
decoder.dateDecodingStrategy = .iso8601

let locale = Locale(identifier: "en_US")              // fixed so the output matches; the app uses .current
let dtos = try decoder.decode([TransactionDTO].self, from: Data(json.utf8))

for dto in dtos {
    do {
        let row = TransactionRowViewData(try Transaction(dto: dto), locale: locale)
        let paddedTitle = row.title.padding(toLength: 14, withPad: " ", startingAt: 0)
        let paddedAmount = row.amountText.padding(toLength: 11, withPad: " ", startingAt: 0)
        print("\(row.isDebit ? "🔴" : "🟢") \(paddedTitle) \(paddedAmount) \(row.dateText)")
    } catch {
        print("⚠️ skipped \(dto.id): \(error) → report it to monitoring, don't show $0.00")
    }
}
