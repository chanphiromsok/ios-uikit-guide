// ✅ IDEA FROM TELEGRAM (`MetaDisposable`): a holder for "the current job". Setting a new one cancels
//    the previous, so only the latest request can update the screen. Written from scratch for Tasks.
// Run: swift examples/16-telegram-patterns/03-latest-only-good.swift
import Foundation

@MainActor
final class LatestTask {
    private var task: Task<Void, Never>?

    /// Cancels the previous job, then starts this one.
    func run(_ operation: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task { await operation() }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

func searchPayees(_ query: String) async throws -> [String] {
    try await Task.sleep(for: .milliseconds(query.count == 1 ? 300 : 100))   // throws CancellationError if cancelled
    return ["\(query) result A", "\(query) result B"]
}

@MainActor
final class PayeeSearchViewController {
    private let search = LatestTask()
    private(set) var shownQuery = ""

    func searchTextChanged(_ query: String) {
        search.run { [weak self] in
            do {
                let results = try await searchPayees(query)
                guard !Task.isCancelled else { return }      // a newer search started while we waited
                self?.shownQuery = query
                print("rendered \(results.count) results for \"\(query)\"")
            } catch {
                print("search for \"\(query)\" cancelled ✅")
            }
        }
    }
}

@MainActor
func demo() async throws {
    let screen = PayeeSearchViewController()
    screen.searchTextChanged("s")
    try await Task.sleep(for: .milliseconds(50))
    screen.searchTextChanged("sok")
    try await Task.sleep(for: .milliseconds(500))
    print("user typed \"sok\", screen shows results for \"\(screen.shownQuery)\" ✅")
}

try await demo()
