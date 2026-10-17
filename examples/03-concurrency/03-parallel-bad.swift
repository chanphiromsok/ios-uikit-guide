// ❌ BAD: independent requests awaited one after another → the screen waits twice as long
// Run: swift examples/03-concurrency/03-parallel-bad.swift
import Foundation

func fetchAccounts() async throws -> [String] {
    try await Task.sleep(for: .seconds(1))            // pretend the network takes 1 s
    return ["Savings USD", "Current KHR"]
}

func fetchProfile() async throws -> String {
    try await Task.sleep(for: .seconds(1))
    return "Sok Dara"
}

let start = ContinuousClock.now
let accounts = try await fetchAccounts()              // waits 1 s…
let profile = try await fetchProfile()                // …THEN waits another 1 s
print(profile, accounts)
let elapsed = ContinuousClock.now - start
print("took \(elapsed.components.seconds) s")
