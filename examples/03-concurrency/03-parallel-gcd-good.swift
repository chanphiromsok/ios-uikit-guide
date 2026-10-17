// ✅ GOOD (GCD style): DispatchGroup runs requests in parallel; you will see this in older codebases
// Run: swift examples/03-concurrency/03-parallel-gcd-good.swift
import Foundation

func fetchAccounts(completion: @escaping @Sendable ([String]) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        let accounts = ["Savings USD", "Current KHR"]
        DispatchQueue.main.async { completion(accounts) }
    }
}

func fetchProfile(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        DispatchQueue.main.async { completion("Sok Dara") }
    }
}

// Results arrive on the main queue, so only the main thread touches this box
final class Results: @unchecked Sendable {
    var accounts: [String] = []
    var profile = ""
}

let start = ContinuousClock.now
let results = Results()
let group = DispatchGroup()

group.enter()
fetchAccounts { accounts in
    results.accounts = accounts
    group.leave()
}

group.enter()
fetchProfile { profile in
    results.profile = profile
    group.leave()
}

group.notify(queue: .main) {
    print(results.profile, results.accounts)
    let elapsed = ContinuousClock.now - start
    print("took \(elapsed.components.seconds) s")
    exit(0)
}
dispatchMain()
