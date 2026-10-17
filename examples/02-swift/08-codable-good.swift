// ✅ GOOD: Codable + CodingKeys → type-safe, and bad data gives a clear error instead of a crash
// Run: swift examples/02-swift/08-codable-good.swift
import Foundation

struct AccountDTO: Decodable {
    let id: String
    let accountNumber: String
    let balance: String          // money as a string → no floating-point errors
    let currency: String

    enum CodingKeys: String, CodingKey {
        case id, balance, currency
        case accountNumber = "acc_no"   // JSON key differs from the Swift name
    }
}

let good = #"{"id":"A1","acc_no":"000123456","balance":"1250.50","currency":"USD"}"#
let broken = #"{"id":"A2","balance":"10.00","currency":"USD"}"#

for json in [good, broken] {
    do {
        let account = try JSONDecoder().decode(AccountDTO.self, from: Data(json.utf8))
        print("✅", account.accountNumber, account.balance, account.currency)
    } catch DecodingError.keyNotFound(let key, _) {
        print("❌ the API forgot the key:", key.stringValue)   // you know exactly what's wrong
    } catch {
        print("❌ decoding failed:", error)
    }
}
