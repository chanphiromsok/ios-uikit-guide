import Testing
@testable import Networking

private actor Counter {
    private(set) var value = 0
    func increment() -> Int { value += 1; return value }
}

@Suite("TokenProvider")
struct TokenProviderTests {
    @Test func manyConcurrent401sRefreshOnce() async throws {
        let counter = Counter()
        let provider = TokenProvider(initialToken: "expired") {
            let n = await counter.increment()
            try await Task.sleep(for: .milliseconds(50))
            return "token-\(n)"
        }

        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<5 {
                group.addTask { try await provider.refreshToken(failed: "expired") }
            }
            var collected: [String] = []
            for try await token in group { collected.append(token) }
            return collected
        }

        #expect(tokens == Array(repeating: "token-1", count: 5))
        #expect(await counter.value == 1)
    }

    @Test func lateFailureAfterARefreshDoesNotRefreshAgain() async throws {
        let counter = Counter()
        let provider = TokenProvider(initialToken: "expired") { "token-\(await counter.increment())" }

        _ = try await provider.refreshToken(failed: "expired")
        let token = try await provider.refreshToken(failed: "expired")   // a slow request reporting the OLD token

        #expect(token == "token-1")
        #expect(await counter.value == 1)
    }

    @Test func noTokenYetTriggersARefresh() async throws {
        let provider = TokenProvider(initialToken: nil) { "fresh" }
        #expect(try await provider.token() == "fresh")
    }
}
