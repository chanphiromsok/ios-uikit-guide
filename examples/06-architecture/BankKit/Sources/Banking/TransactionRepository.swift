import Foundation
import Networking

public protocol TransactionsAPI: Sendable {
    func fetchTransactions() async throws -> [TransactionDTO]
}

public struct LiveTransactionsAPI: TransactionsAPI {
    private let client: APIClient

    public init(client: APIClient) { self.client = client }

    public func fetchTransactions() async throws -> [TransactionDTO] {
        try await client.get("v1/transactions")
    }
}

/// Cache with TTL + request de-duplication + invalidation.
public actor TransactionRepository {
    private let api: any TransactionsAPI
    private let ttl: Duration
    private var cached: (value: [Transaction], fetchedAt: ContinuousClock.Instant)?
    private var inFlight: Task<[Transaction], Error>?

    public init(api: any TransactionsAPI, ttl: Duration = .seconds(60)) {
        self.api = api
        self.ttl = ttl
    }

    public func transactions(forceRefresh: Bool = false) async throws -> [Transaction] {
        if !forceRefresh, let cached, ContinuousClock.now - cached.fetchedAt < ttl {
            return cached.value
        }
        if let inFlight { return try await inFlight.value }

        let task = Task { try await api.fetchTransactions().map(Transaction.init(dto:)) }
        inFlight = task
        defer { inFlight = nil }

        let value = try await task.value
        cached = (value, ContinuousClock.now)
        return value
    }

    public func invalidate() { cached = nil }
}
