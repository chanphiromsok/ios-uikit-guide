import Foundation

public enum Currency: String, Sendable {
    case usd = "USD"
    case khr = "KHR"
}

public struct Money: Hashable, Sendable {
    public let amount: Decimal
    public let currency: Currency

    public init(amount: Decimal, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    /// USD with cents ("-$4.50"); KHR without decimals ("-50,000 ៛").
    public func displayText(locale: Locale = .current) -> String {
        switch currency {
        case .usd: return amount.formatted(.currency(code: "USD").locale(locale))
        case .khr: return amount.formatted(.number.precision(.fractionLength(0)).locale(locale)) + " ៛"
        }
    }
}
