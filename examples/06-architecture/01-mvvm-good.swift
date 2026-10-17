// ✅ GOOD: MVVM: the ViewModel holds the logic and state, with no UIKit → it can be unit-tested in milliseconds
// Run: swift examples/06-architecture/01-mvvm-good.swift
import Foundation

struct Account: Sendable {
    let name: String
    let balance: Decimal
}

protocol AccountsRepository: Sendable {
    func accounts() async throws -> [Account]
}

struct AccountRowViewData: Equatable {
    let title: String
    let balanceText: String
    let showsLowBalanceWarning: Bool
}

@MainActor
final class AccountsViewModel {
    enum State: Equatable {
        case loading
        case loaded([AccountRowViewData])
        case empty
        case failed(String)
    }

    private(set) var state: State = .loading
    var onOpenAccount: (() -> Void)?                 // navigation is the Coordinator's job

    private let repository: any AccountsRepository
    private let locale: Locale

    init(repository: any AccountsRepository, locale: Locale = .current) {
        self.repository = repository
        self.locale = locale
    }

    func load() async {
        do {
            let accounts = try await repository.accounts()
            state = accounts.isEmpty ? .empty : .loaded(accounts.map(makeRow))
        } catch {
            state = .failed("Couldn't load accounts")
        }
    }

    func openAccountTapped() { onOpenAccount?() }

    private func makeRow(_ account: Account) -> AccountRowViewData {
        AccountRowViewData(
            title: account.name,
            balanceText: account.balance.formatted(.currency(code: "USD").locale(locale)),
            showsLowBalanceWarning: account.balance < 10
        )
    }
}

// The view controller only renders `state` and forwards taps.
// Below are real "unit tests" against the ViewModel: no UI, no network.

struct StubRepository: AccountsRepository {
    let result: Result<[Account], any Error>
    func accounts() async throws -> [Account] { try result.get() }
}

struct Offline: Error {}

func check(_ name: String, _ condition: Bool) { print(condition ? "✅" : "❌", name) }
func usd(_ text: String) -> Decimal { Decimal(string: text) ?? 0 }
let english = Locale(identifier: "en_US")

let lowBalance = AccountsViewModel(
    repository: StubRepository(result: .success([Account(name: "Wallet", balance: usd("3.20"))])), locale: english)
await lowBalance.load()
check("low balance shows a warning",
      lowBalance.state == .loaded([AccountRowViewData(title: "Wallet", balanceText: "$3.20", showsLowBalanceWarning: true)]))

let noAccounts = AccountsViewModel(repository: StubRepository(result: .success([])), locale: english)
await noAccounts.load()
check("no accounts → empty state", noAccounts.state == .empty)

let offline = AccountsViewModel(repository: StubRepository(result: .failure(Offline())), locale: english)
await offline.load()
check("offline → error state", offline.state == .failed("Couldn't load accounts"))

var openedAccountScreen = false
noAccounts.onOpenAccount = { openedAccountScreen = true }
noAccounts.openAccountTapped()
check("tap 'Open account' asks the coordinator to navigate", openedAccountScreen)
