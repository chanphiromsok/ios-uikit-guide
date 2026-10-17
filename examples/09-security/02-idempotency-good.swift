// ✅ GOOD: one idempotency key per transfer, reused on every retry → the server charges once
// Run: swift examples/09-security/02-idempotency-good.swift
import Foundation

struct Timeout: Error {}

// Fake bank server. The FIRST response is lost on the way back (bad mobile network):
// the money has moved, but the app only sees a timeout.
actor FakeBankServer {
    private(set) var balance: Decimal = 100
    private var receiptsByKey: [String: String] = [:]
    private var receiptCount = 0
    private var loseNextResponse = true

    func transfer(amount: Decimal, idempotencyKey: String?) throws -> String {
        if let idempotencyKey, let receipt = receiptsByKey[idempotencyKey] {
            return receipt                                   // already done → do NOT charge again
        }
        balance -= amount
        receiptCount += 1
        let receipt = "RCPT-\(receiptCount)"
        if let idempotencyKey { receiptsByKey[idempotencyKey] = receipt }
        if loseNextResponse {
            loseNextResponse = false
            throw Timeout()
        }
        return receipt
    }
}

func sendTransfer(_ amount: Decimal, server: FakeBankServer) async throws -> String {
    let idempotencyKey = UUID().uuidString            // created ONCE, when the user taps "Confirm"
    for attempt in 1...2 {
        do {
            return try await server.transfer(amount: amount, idempotencyKey: idempotencyKey)
        } catch is Timeout {
            print("attempt \(attempt): timeout → retrying with the same key…")
        }
    }
    throw Timeout()
}

let server = FakeBankServer()
let receipt = try await sendTransfer(20, server: server)
print("receipt:", receipt)
print("balance: $\(await server.balance)  (started at $100, sent $20) ✅ charged once")
