// ✅ GOOD: one TokenProvider actor → many 401s, exactly ONE refresh, everyone retries with the new token
// Run: swift examples/04-networking/04-token-refresh-good.swift

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

actor TokenProvider {
    private let server: FakeAuthServer
    private var accessToken: String
    private var refreshTask: Task<String, Error>?

    init(server: FakeAuthServer, initialToken: String) {
        self.server = server
        self.accessToken = initialToken
    }

    func token() -> String { accessToken }

    func refreshToken(failed oldToken: String) async throws -> String {
        if accessToken != oldToken { return accessToken }        // someone already refreshed
        if let refreshTask { return try await refreshTask.value } // a refresh is running → wait for it

        let task = Task { try await server.refresh() }
        refreshTask = task
        defer { refreshTask = nil }

        let newToken = try await task.value                      // if this throws → log the user out
        accessToken = newToken
        return newToken
    }
}

struct APIClient: Sendable {
    let server: FakeAuthServer
    let tokens: TokenProvider

    func get(_ path: String) async throws -> String {
        let token = await tokens.token()
        do {
            return try await server.get(path, token: token)
        } catch is Unauthorized {
            let newToken = try await tokens.refreshToken(failed: token)
            return try await server.get(path, token: newToken)
        }
    }
}

let server = FakeAuthServer()
let client = APIClient(server: server, tokens: TokenProvider(server: server, initialToken: "token-0"))
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
print("refresh calls:", await server.refreshCount)
