// 🧑‍💻 Interview live-coding practice: solutions + self-checks. Try each one yourself first!
// Run: swift examples/12-interview/live-coding.swift
import Foundation

// 1. Mask an account number: "000123456" → "•••••3456"
func maskAccount(_ number: String) -> String {
    let digits = number.filter(\.isNumber)
    guard digits.count > 4 else { return digits }
    return String(repeating: "•", count: digits.count - 4) + digits.suffix(4)
}

// 2. Group thousands without NumberFormatter: 1250000 → "1,250,000"
func groupThousands(_ n: Int) -> String {
    let digits = String(n.magnitude)
    let count = digits.count
    var out = ""
    for (i, ch) in digits.enumerated() {
        if i > 0 && (count - i) % 3 == 0 { out.append(",") }
        out.append(ch)
    }
    return n < 0 ? "-" + out : out
}

// 3. Validate a Cambodian mobile number (simplified rule): +855 12 345 678 or 012 345 678
func isCambodianMobile(_ input: String) -> Bool {
    var digits = input.filter(\.isNumber)
    if digits.hasPrefix("855") { digits = "0" + digits.dropFirst(3) }
    return digits.hasPrefix("0")
        && (9...10).contains(digits.count)
        && digits.dropFirst().first != "0"
}

// 4. Parse an EMVCo / KHQR payload: TAG(2) LENGTH(2) VALUE… (simplified: ASCII only)
func parseTLV(_ payload: String) -> [String: String]? {
    var result: [String: String] = [:]
    var index = payload.startIndex
    while index < payload.endIndex {
        guard let tagEnd = payload.index(index, offsetBy: 2, limitedBy: payload.endIndex),
              let lengthEnd = payload.index(tagEnd, offsetBy: 2, limitedBy: payload.endIndex),
              let length = Int(payload[tagEnd..<lengthEnd]),
              let valueEnd = payload.index(lengthEnd, offsetBy: length, limitedBy: payload.endIndex)
        else { return nil }
        result[String(payload[index..<tagEnd])] = String(payload[lengthEnd..<valueEnd])
        index = valueEnd
    }
    return result
}

// 5. KHQR checksum: CRC-16/CCITT-FALSE over everything up to and including "6304"
func crc16CCITTFalse(_ data: Data) -> UInt16 {
    var crc: UInt16 = 0xFFFF
    for byte in data {
        crc ^= UInt16(byte) << 8
        for _ in 0..<8 {
            crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
        }
    }
    return crc
}

func hasValidCRC(_ payload: String) -> Bool {
    guard payload.count > 8, payload.dropLast(4).hasSuffix("6304") else { return false }
    guard let expected = UInt16(payload.suffix(4), radix: 16) else { return false }
    return crc16CCITTFalse(Data(payload.dropLast(4).utf8)) == expected
}

// ── Self-checks ─────────────────────────────────────────────────────────────────────
func check(_ name: String, _ condition: Bool) { print(condition ? "✅" : "❌", name) }

check("mask 000123456", maskAccount("000123456") == "•••••3456")
check("mask with spaces", maskAccount("000 123 456") == "•••••3456")
check("group 1250000", groupThousands(1_250_000) == "1,250,000")
check("group -999", groupThousands(-999) == "-999")
check("group 1000", groupThousands(1_000) == "1,000")
check("+855 12 345 678 is valid", isCambodianMobile("+855 12 345 678"))
check("012345678 is valid", isCambodianMobile("012345678"))
check("12345 is invalid", !isCambodianMobile("12345"))
check("CRC check value of \"123456789\" is 0x29B1", crc16CCITTFalse(Data("123456789".utf8)) == 0x29B1)

// Build a KHQR-shaped payload (simplified), then parse and validate it
func tlv(_ tag: String, _ value: String) -> String { tag + String(format: "%02d", value.count) + value }

var payload = tlv("00", "01") + tlv("01", "12") + tlv("52", "5999") + tlv("53", "116") + tlv("54", "50000")
    + tlv("58", "KH") + tlv("59", "Lucky Market") + tlv("60", "Phnom Penh") + "6304"
payload += String(format: "%04X", crc16CCITTFalse(Data(payload.utf8)))

print("\nKHQR payload:", payload)
if let tags = parseTLV(payload) {
    let currency = tags["53"] == "116" ? "KHR" : (tags["53"] == "840" ? "USD" : "?")
    print("merchant: \(tags["59"] ?? "?"), city: \(tags["60"] ?? "?"), amount: \(tags["54"] ?? "?") \(currency)")
}
check("valid payload passes the CRC check", hasValidCRC(payload))

let tampered = payload.replacingOccurrences(of: "540550000", with: "540590000")   // 50000 → 90000
check("tampered amount fails the CRC check", !hasValidCRC(tampered))
