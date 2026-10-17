// ❌ BAD: every keystroke starts a search and nothing cancels the old ones → a slow, old result
//         can arrive LAST and overwrite the newest one
// Run: swift examples/16-telegram-patterns/03-latest-only-bad.swift
import Foundation

func searchPayees(_ query: String) async throws -> [String] {
    try await Task.sleep(for: .milliseconds(query.count == 1 ? 300 : 100))   // short queries are slower
    return ["\(query) result A", "\(query) result B"]
}

@MainActor
final class PayeeSearchViewController {
    private(set) var shownQuery = ""

    func searchTextChanged(_ query: String) {
        Task {
            guard let results = try? await searchPayees(query) else { return }
            shownQuery = query                               // ❌ whoever finishes last wins
            print("rendered \(results.count) results for \"\(query)\"")
        }
    }
}

@MainActor
func demo() async throws {
    let screen = PayeeSearchViewController()
    screen.searchTextChanged("s")                            // slow
    try await Task.sleep(for: .milliseconds(50))
    screen.searchTextChanged("sok")                          // fast
    try await Task.sleep(for: .milliseconds(500))
    print("user typed \"sok\", screen shows results for \"\(screen.shownQuery)\" ❌")
}

try await demo()
