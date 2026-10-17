// ❌ BAD: the ViewModel reaches for a singleton → you can't test it without the real server
// Run: swift examples/02-swift/07-dependency-injection-bad.swift

final class APIService: Sendable {
    static let shared = APIService()

    func fetchBalance() async throws -> String {
        print("  🌐 calling https://api.mybank.com/v1/balance … (needs internet, a real account, a real server)")
        return "$1,250.50"
    }
}

@MainActor
final class HomeViewModel {
    private(set) var balanceText = "–"

    func load() async {
        do {
            balanceText = try await APIService.shared.fetchBalance()   // hard-wired dependency
        } catch {
            balanceText = "Unavailable"
        }
    }
}

let viewModel = HomeViewModel()
await viewModel.load()
print("balance shown:", viewModel.balanceText)
print("How do you test the 'Unavailable' case? You can't, without breaking the real server.")
