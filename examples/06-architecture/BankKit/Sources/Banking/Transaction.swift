import Foundation

/// Mirrors the API exactly.
public struct TransactionDTO: Decodable, Sendable {
    public let id: String
    public let amount: String            // money as a string, never Double
    public let currency: String
    public let bookedAt: Date
    public let merchantName: String?

    public init(id: String, amount: String, currency: String, bookedAt: Date, merchantName: String?) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.bookedAt = bookedAt
        self.merchantName = merchantName
    }
}

public enum MappingError: Error, Equatable {
    case invalidAmount(String)
    case unknownCurrency(String)
}

/// What the app reasons about.
public struct Transaction: Sendable, Identifiable {
    public let id: String
    public let money: Money
    public let date: Date
    public let merchant: String

    public init(dto: TransactionDTO) throws {
        guard let amount = Decimal(string: dto.amount) else { throw MappingError.invalidAmount(dto.amount) }
        guard let currency = Currency(rawValue: dto.currency) else { throw MappingError.unknownCurrency(dto.currency) }
        id = dto.id
        money = Money(amount: amount, currency: currency)
        date = dto.bookedAt
        merchant = dto.merchantName ?? "Unknown merchant"
    }
}

/// Display-ready: the cell does no logic.
public struct TransactionRowViewData: Hashable, Sendable {
    public let id: String
    public let title: String
    public let amountText: String
    public let isDebit: Bool

    public init(_ transaction: Transaction, locale: Locale = .current) {
        id = transaction.id
        title = transaction.merchant
        amountText = transaction.money.displayText(locale: locale)
        isDebit = transaction.money.amount < 0
    }
}
