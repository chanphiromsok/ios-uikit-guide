// ✅ GOOD: an actor repository with TTL, request de-duplication and invalidation (a tiny React Query)
// Run: swift examples/04-networking/03-caching-good.swift

actor FakeAccountsAPI {
    private(set) var callCount = 0

    func fetchAccounts() async throws -> [String] {
        callCount += 1
        try await Task.sleep(for: .milliseconds(200))
        return ["Savings USD: $1,250.50", "Current KHR: 50,000 ៛"]
    }
}

actor AccountRepository {
    private let api: FakeAccountsAPI
    private let ttl: Duration
    private var cached: (value: [String], fetchedAt: ContinuousClock.Instant)?
    private var inFlight: Task<[String], Error>?

    init(api: FakeAccountsAPI, ttl: Duration = .seconds(60)) {
        self.api = api
        self.ttl = ttl
    }

    func accounts(forceRefresh: Bool = false) async throws -> [String] {
        if !forceRefresh, let cached, ContinuousClock.now - cached.fetchedAt < ttl {
            return cached.value                               // fresh cache hit
        }
        if let inFlight { return try await inFlight.value }  // someone is already fetching → share it

        let task = Task { try await api.fetchAccounts() }
        inFlight = task
        defer { inFlight = nil }

        let value = try await task.value
        cached = (value, ContinuousClock.now)
        return value
    }

    func invalidate() { cached = nil }                       // call after a transfer, and on logout
}

let api = FakeAccountsAPI()
let repository = AccountRepository(api: api)

async let home = repository.accounts()
async let transfer = repository.accounts()
async let khqr = repository.accounts()
_ = try await (home, transfer, khqr)
print("API calls at launch (3 screens):", await api.callCount)            // 1

_ = try await repository.accounts()
print("API calls after going back to Home:", await api.callCount)         // still 1 (cache hit)

await repository.invalidate()                                             // a transfer changed the balance
_ = try await repository.accounts()
print("API calls after a transfer + invalidate():", await api.callCount)  // 2
