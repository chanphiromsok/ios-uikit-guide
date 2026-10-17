// ✅ GOOD: a small API client that checks the status code and turns every failure into a clear error
// Run: swift examples/04-networking/01-fetch-good.swift
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

enum APIError: Error {
    case offline
    case server(statusCode: Int)
    case invalidData
}

struct APIClient: Sendable {
    let baseURL: URL
    let session: URLSession            // banking: URLSession(configuration: .ephemeral) → nothing cached on disk

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(statusCode) else { throw APIError.server(statusCode: statusCode) }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidData
        }
    }
}

struct Account: Decodable {
    let id: String
    let balance: String
}

FakeServer.routes = [
    "/v1/accounts": (status: 200, body: #"[{"id":"A1","balance":"1250.50"},{"id":"A2","balance":"50000"}]"#),
    "/v1/broken":   (status: 500, body: "<html>Internal Server Error</html>"),
    "/v1/wifi":     (status: 200, body: "<html>Hotel Wi-Fi: please log in</html>"),
]

guard let baseURL = URL(string: "https://api.mybank.example") else { fatalError("bad base URL") }
let api = APIClient(baseURL: baseURL, session: FakeServer.session())

for path in ["v1/accounts", "v1/broken", "v1/wifi"] {
    do {
        let accounts: [Account] = try await api.get(path)
        print("✅ \(path): \(accounts.count) accounts")
    } catch {
        print("⚠️ \(path): \(error) → show a friendly message + [Try again]")
    }
}
