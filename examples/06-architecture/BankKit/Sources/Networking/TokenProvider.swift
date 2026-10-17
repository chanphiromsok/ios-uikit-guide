/// Holds the access token. Many concurrent 401s → exactly one refresh.
public actor TokenProvider {
    private var accessToken: String?
    private var refreshTask: Task<String, Error>?
    private let refresh: @Sendable () async throws -> String   // calls your /auth/refresh endpoint

    public init(initialToken: String?, refresh: @escaping @Sendable () async throws -> String) {
        self.accessToken = initialToken
        self.refresh = refresh
    }

    public func token() async throws -> String {
        if let accessToken { return accessToken }
        return try await refreshToken(failed: nil)
    }

    public func refreshToken(failed oldToken: String?) async throws -> String {
        if let accessToken, accessToken != oldToken { return accessToken }   // already refreshed by someone else
        if let refreshTask { return try await refreshTask.value }           // a refresh is running → wait

        let task = Task { try await refresh() }
        refreshTask = task
        defer { refreshTask = nil }

        let newToken = try await task.value      // if this throws, the app should log the user out
        accessToken = newToken
        return newToken
    }

    public func clear() { accessToken = nil }    // on logout
}
