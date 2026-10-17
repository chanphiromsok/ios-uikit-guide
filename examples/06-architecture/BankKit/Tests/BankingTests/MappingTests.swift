import Foundation
import Testing
@testable import Banking

private let english = Locale(identifier: "en_US")

private func dto(amount: String, currency: String = "USD", merchant: String? = "Coffee Shop") -> TransactionDTO {
    TransactionDTO(id: "T1", amount: amount, currency: currency, bookedAt: Date(timeIntervalSince1970: 0), merchantName: merchant)
}

@Suite("DTO → Domain → ViewData")
struct MappingTests {
    @Test func mapsAValidTransaction() throws {
        let transaction = try Transaction(dto: dto(amount: "-4.50"))
        #expect(transaction.money == Money(amount: Decimal(string: "-4.50")!, currency: .usd))
        #expect(transaction.merchant == "Coffee Shop")
    }

    @Test func rejectsAnInvalidAmount() {
        #expect(throws: MappingError.invalidAmount("abc")) { try Transaction(dto: dto(amount: "abc")) }
    }

    @Test func rejectsAnUnknownCurrency() {
        #expect(throws: MappingError.unknownCurrency("EUR")) { try Transaction(dto: dto(amount: "1", currency: "EUR")) }
    }

    @Test func missingMerchantGetsAFallbackName() throws {
        #expect(try Transaction(dto: dto(amount: "1", merchant: nil)).merchant == "Unknown merchant")
    }

    @Test(arguments: [
        ("-4.50", "USD", "-$4.50"),
        ("1250.5", "USD", "$1,250.50"),
        ("-50000", "KHR", "-50,000 ៛"),
    ])
    func formatsMoneyForDisplay(amount: String, currency: String, expected: String) throws {
        let row = TransactionRowViewData(try Transaction(dto: dto(amount: amount, currency: currency)), locale: english)
        #expect(row.amountText == expected)
    }
}
