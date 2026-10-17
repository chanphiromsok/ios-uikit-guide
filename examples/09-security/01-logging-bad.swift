// ❌ BAD: logging secrets and personal data → they end up in device logs, crash reports and analytics
// Run: swift examples/09-security/01-logging-bad.swift

let accessToken = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.sig"
let fromAccount = "000123456"
let toAccount = "000987654"
let pin = "1234"

print("POST /v1/transfers Authorization: Bearer \(accessToken)")
print("transfer $20.00 from \(fromAccount) to \(toAccount), pin=\(pin)")
