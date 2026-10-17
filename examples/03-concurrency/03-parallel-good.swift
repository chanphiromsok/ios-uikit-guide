// ✅ GOOD: async let runs independent requests at the same time (like Promise.all)
// Run: swift examples/03-concurrency/03-parallel-good.swift
import Foundation

func fetchAccounts() async throws -> [String] {
    try await Task.sleep(for: .seconds(1))
    return ["Savings USD", "Current KHR"]
}

func fetchProfile() async throws -> String {
    try await Task.sleep(for: .seconds(1))
    return "Sok Dara"
}

let start = ContinuousClock.now
async let accounts = fetchAccounts()                  // starts now
async let profile = fetchProfile()                    // also starts now
let (a, p) = try await (accounts, profile)            // wait for both
print(p, a)
let elapsed = ContinuousClock.now - start
print("took \(elapsed.components.seconds) s")
