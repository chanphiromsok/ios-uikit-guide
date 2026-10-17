import Foundation
import Testing
@testable import Banking

private actor CountingAPI: TransactionsAPI {
    private(set) var calls = 0

    func fetchTransactions() async throws -> [TransactionDTO] {
        calls += 1
        try await Task.sleep(for: .milliseconds(50))
        return [TransactionDTO(id: "T1", amount: "-4.50", currency: "USD", bookedAt: .now, merchantName: "Coffee Shop")]
    }
}

@Suite("TransactionRepository")
struct RepositoryTests {
    @Test func concurrentCallsHitTheAPIOnce() async throws {
        let api = CountingAPI()
        let repository = TransactionRepository(api: api)

        async let home = repository.transactions()
        async let history = repository.transactions()
        async let search = repository.transactions()
        _ = try await (home, history, search)

        #expect(await api.calls == 1)
    }

    @Test func freshCacheIsReused() async throws {
        let api = CountingAPI()
        let repository = TransactionRepository(api: api)
        _ = try await repository.transactions()
        _ = try await repository.transactions()
        #expect(await api.calls == 1)
    }

    @Test func invalidateForcesANewFetch() async throws {
        let api = CountingAPI()
        let repository = TransactionRepository(api: api)
        _ = try await repository.transactions()
        await repository.invalidate()
        _ = try await repository.transactions()
        #expect(await api.calls == 2)
    }

    @Test func expiredCacheIsRefetched() async throws {
        let api = CountingAPI()
        let repository = TransactionRepository(api: api, ttl: .milliseconds(10))
        _ = try await repository.transactions()
        try await Task.sleep(for: .milliseconds(30))
        _ = try await repository.transactions()
        #expect(await api.calls == 2)
    }
}
