//! expect: crash
// ❌ BAD: ignores the HTTP status, uses try! and force unwraps → one server hiccup crashes the app
// Run: swift examples/04-networking/01-fetch-bad.swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking        // Linux only; not needed on iOS
#endif

// ── Fake server: lets this file run offline. Test scaffolding only; not part of the app. ──
final class FakeServer: URLProtocol {
    nonisolated(unsafe) static var routes: [String: (status: Int, body: String)] = [:]

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeServer.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        guard let url = request.url else { return }
        let route = Self.routes[url.path] ?? (status: 404, body: "")
        let response = HTTPURLResponse(url: url, statusCode: route.status, httpVersion: nil, headerFields: nil)
        if let response { client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
        client?.urlProtocol(self, didLoad: Data(route.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
// ─────────────────────────────────────────────────────────────────────────────────────────

struct Account: Decodable {
    let id: String
    let balance: String
}

let session = FakeServer.session()
FakeServer.routes["/v1/accounts"] = (status: 500, body: "<html>Internal Server Error</html>")  // a bad day

func loadAccounts() async -> [Account] {
    let url = URL(string: "https://api.mybank.example/v1/accounts")!
    let (data, _) = try! await session.data(from: url)           // offline → 💥
    return try! JSONDecoder().decode([Account].self, from: data) // error page instead of JSON → 💥
}

print("Loading accounts…")
let accounts = await loadAccounts()
print("Loaded \(accounts.count) accounts")
