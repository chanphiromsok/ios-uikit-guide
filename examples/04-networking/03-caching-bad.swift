// ❌ BAD: a naive cache: no de-duplication, no expiry, no invalidation
// Run: swift examples/04-networking/03-caching-bad.swift

actor FakeAccountsAPI {
    private(set) var callCount = 0

    func fetchAccounts() async throws -> [String] {
        callCount += 1
        try await Task.sleep(for: .milliseconds(200))       // pretend this is the network
        return ["Savings USD: $1,250.50", "Current KHR: 50,000 ៛"]
    }
}

@MainActor
final class AccountRepository {
    private let api: FakeAccountsAPI
    private var cache: [String]?

    init(api: FakeAccountsAPI) { self.api = api }

    func accounts() async throws -> [String] {
        if let cache { return cache }
        let fresh = try await api.fetchAccounts()            // 3 screens can all get here at the same time
        cache = fresh
        return fresh
    }
    // ❌ no expiry: the balance can stay stale forever
    // ❌ no invalidate(): after a transfer the old balance is still shown
}

let api = FakeAccountsAPI()
let repository = AccountRepository(api: api)

// Home, Transfer and KHQR screens all load accounts at launch
async let home = repository.accounts()
async let transfer = repository.accounts()
async let khqr = repository.accounts()
_ = try await (home, transfer, khqr)
print("API calls at launch (3 screens):", await api.callCount)    // 3: the cache didn't help
