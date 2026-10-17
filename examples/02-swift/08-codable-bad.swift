//! expect: crash
// ❌ BAD: parsing JSON by hand with [String: Any] and force casts
// Run: swift examples/02-swift/08-codable-bad.swift
import Foundation

let json = #"{"id":"A1","acc_no":"000123456","balance":"1250.50","currency":"USD"}"#

let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
let accountNumber = object["account_number"] as? String   // typo in the key → silently nil
print("account number:", accountNumber ?? "nil 🤷")
let balance = object["balance"] as! Double                // 💥 it's a String in the JSON
print("balance:", balance)
