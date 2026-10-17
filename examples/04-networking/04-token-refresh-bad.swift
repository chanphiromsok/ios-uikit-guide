//! output: varies
// ❌ BAD: every request that gets a 401 refreshes the token by itself
// Run: swift examples/04-networking/04-token-refresh-bad.swift

struct Unauthorized: Error {}

// Fake auth server: every refresh issues a NEW token and the old one stops working (token rotation)
actor FakeAuthServer {
    private(set) var refreshCount = 0
    private var validToken: String? = nil                  // the app's current token has just expired

    func refresh() async throws -> String {
        refreshCount += 1
        let token = "token-\(refreshCount)"
        try await Task.sleep(for: .milliseconds(100))
        validToken = token
        return token
    }

    func get(_ path: String, token: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(50))
        guard token == validToken else { throw Unauthorized() }
        return path
    }
}

@MainActor
final class NaiveAPIClient {
    private let server: FakeAuthServer
    private var token = "token-0"

    init(server: FakeAuthServer) { self.server = server }

    func get(_ path: String) async throws -> String {
        do {
            return try await server.get(path, token: token)
        } catch is Unauthorized {
            token = try await server.refresh()                      // ❌ 5 requests → 5 refreshes
            return try await server.get(path, token: token)
        }
    }
}

let server = FakeAuthServer()
let client = NaiveAPIClient(server: server)
let paths = ["/accounts", "/profile", "/cards", "/transactions", "/notifications"]

let results = await withTaskGroup(of: String.self) { group in
    for path in paths {
        group.addTask {
            do { return "✅ \(try await client.get(path))" } catch { return "❌ \(path): 401 again" }
        }
    }
    var collected: [String] = []
    for await result in group { collected.append(result) }
    return collected.sorted()
}

results.forEach { print($0) }
print("refresh calls:", await server.refreshCount, "→ each refresh killed the previous token")
