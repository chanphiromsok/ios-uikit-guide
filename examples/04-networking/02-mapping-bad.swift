// ❌ BAD: the "cell" gets the raw API model and parses, formats and decides everything itself
// Run: swift examples/04-networking/02-mapping-bad.swift
import Foundation

struct TransactionDTO: Decodable {
    let id: String
    let amount: String
    let currency: String
    let merchant_name: String?          // API naming leaks into the whole app
}

func configureCell(with dto: TransactionDTO) -> String {
    let amount = Double(dto.amount) ?? 0                       // bad data silently becomes 0, money as Double
    let text = String(format: "$%.2f", amount)                // "$" even for riel!
    return "\(dto.merchant_name ?? "")  \(text)"
}

let fromAPI = [
    TransactionDTO(id: "T1", amount: "-4.50", currency: "USD", merchant_name: "Coffee Shop"),
    TransactionDTO(id: "T2", amount: "-50000", currency: "KHR", merchant_name: "Lucky Market"),
    TransactionDTO(id: "T3", amount: "abc", currency: "USD", merchant_name: nil),
]

for dto in fromAPI {
    print(configureCell(with: dto))
}
print("→ riel shown as dollars, a broken amount shown as $0.00, and none of this is testable without a cell")
