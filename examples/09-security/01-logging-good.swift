// ✅ GOOD: redact before logging; never log PINs at all
// Run: swift examples/09-security/01-logging-good.swift
// On iOS, send the message to os.Logger:  Logger.transfer.info("\(message, privacy: .public)")
// or log raw values with `privacy: .private` so they are hidden in production logs.

enum Redact {
    static func account(_ number: String) -> String {
        let digits = number.filter(\.isNumber)
        guard digits.count > 4 else { return String(repeating: "•", count: digits.count) }
        return String(repeating: "•", count: digits.count - 4) + digits.suffix(4)
    }

    static func token(_ token: String) -> String {
        token.isEmpty ? "<none>" : "<redacted, \(token.count) chars>"
    }
}

let accessToken = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.sig"
let fromAccount = "000123456"
let toAccount = "000987654"

print("POST /v1/transfers Authorization: \(Redact.token(accessToken))")
print("transfer $20.00 from \(Redact.account(fromAccount)) to \(Redact.account(toAccount))")
