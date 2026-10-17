import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum APIError: Error, Equatable {
    case offline
    case server(statusCode: Int)
    case invalidData
}

/// Small JSON client: adds the bearer token, checks the status code, retries once after a 401.
public struct APIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let tokens: TokenProvider?

    public init(baseURL: URL, session: URLSession = URLSession(configuration: .ephemeral), tokens: TokenProvider? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.tokens = tokens
    }

    public func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await send(request)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidData
        }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        var request = request
        let token = try await tokens?.token()
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        var (data, status) = try await perform(request)
        if status == 401, let tokens {
            let newToken = try await tokens.refreshToken(failed: token)
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            (data, status) = try await perform(request)
        }

        guard (200..<300).contains(status) else { throw APIError.server(statusCode: status) }
        return data
    }

    private func perform(_ request: URLRequest) async throws -> (Data, Int) {
        do {
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? -1)
        } catch {
            throw APIError.offline
        }
    }
}
