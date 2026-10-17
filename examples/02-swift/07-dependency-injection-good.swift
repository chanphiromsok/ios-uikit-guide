// ✅ GOOD: depend on a protocol and inject it → swap in a mock for tests, previews and the Dev scheme
// Run: swift examples/02-swift/07-dependency-injection-good.swift

protocol BalanceProviding: Sendable {
    func fetchBalance() async throws -> String
}

struct LiveBalanceAPI: BalanceProviding {
    func fetchBalance() async throws -> String {
        // real URLSession call goes here (see examples/04-networking)
        "$1,250.50"
    }
}

struct MockBalanceAPI: BalanceProviding {
    struct Offline: Error {}
    var result: Result<String, Offline>
    func fetchBalance() async throws -> String { try result.get() }
}

@MainActor
final class HomeViewModel {
    private let api: any BalanceProviding
    private(set) var balanceText = "–"

    init(api: any BalanceProviding) { self.api = api }      // injected

    func load() async {
        do {
            balanceText = try await api.fetchBalance()
        } catch {
            balanceText = "Unavailable"
        }
    }
}

// "Tests": no network needed, every case is easy to reproduce
let happy = HomeViewModel(api: MockBalanceAPI(result: .success("$99.00")))
await happy.load()
print(happy.balanceText == "$99.00" ? "✅ shows balance" : "❌ failed")

let offline = HomeViewModel(api: MockBalanceAPI(result: .failure(.init())))
await offline.load()
print(offline.balanceText == "Unavailable" ? "✅ shows 'Unavailable' when offline" : "❌ failed")

// In the real app
let live = HomeViewModel(api: LiveBalanceAPI())
await live.load()
print("live app shows:", live.balanceText)
