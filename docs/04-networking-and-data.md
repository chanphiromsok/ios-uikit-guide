# 04 · Networking and the data layer

[← Index](../README.md) · [← Concurrency](03-concurrency.md) · [Next: UIKit →](05-uikit.md)

```
API JSON ──▶ DTO (Codable) ──▶ Domain model ──▶ ViewData (strings, colors) ──▶ Cell
             mirrors the API    business rules   display-ready, no logic left
```

There's no built-in React Query on iOS. You build these layers yourself: an **API client**, **mapping**, a **repository** with caching, and a **token provider**. All examples are 🐧 and run offline against a fake server.

| Topic | Bad | Good |
|---|---|---|
| [4.1 Fetching](#41-fetching-with-urlsession) | `try!`, no status check | API client with clear errors |
| [4.2 Mapping](#42-dto--domain--viewdata) | cell parses raw JSON | DTO → Domain → ViewData |
| [4.3 Caching](#43-caching-and-invalidation) | naive cache | actor: TTL + dedupe + invalidate |
| [4.4 Token refresh](#44-token-refresh-the-classic-senior-question) | every 401 refreshes | one refresh for everyone |

---

## 4.1 Fetching with URLSession

**Why it matters:**
- **Status codes:** `URLSession` doesn't throw for a 500 or 404. It hands you the error page as `Data`. Check the status yourself.
- **No `try!`:** turn every failure into an error the UI can explain. Mobile networks fail all the time.

### ❌ Bad

<!-- example: examples/04-networking/01-fetch-bad.swift -->
```swift
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
```

**Output**

```text
Loading accounts…
01-fetch-bad.swift:44: Fatal error: 'try!' expression unexpectedly raised an error: DecodingError.dataCorrupted: Data was corrupted. Debug description: The given data was not valid JSON.
💥 (the app crashes here; stack trace omitted)
```
<!-- /example -->

### ✅ Good

<!-- example: examples/04-networking/01-fetch-good.swift -->
```swift
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
```

**Output**

```text
✅ v1/accounts: 2 accounts
⚠️ v1/broken: server(statusCode: 500) → show a friendly message + [Try again]
⚠️ v1/wifi: invalidData → show a friendly message + [Try again]
```
<!-- /example -->

> **Banking:** use `URLSession(configuration: .ephemeral)` for authenticated calls: no disk cache, no stored cookies or credentials.

---

## 4.2 DTO → Domain → ViewData

**Why it matters:**
- **Rules in one place:** when the cell parses and formats raw API data, every screen re-implements the rules, differently.
- **Testability:** three small models give you one place per job, each easy to test.
- **No hidden bad data:** broken data gets *reported* instead of shown as `$0.00`.

### ❌ Bad

<!-- example: examples/04-networking/02-mapping-bad.swift -->
```swift
// ❌ BAD: the "cell" gets the raw API model and parses, formats and decides everything itself
// Run: swift examples/04-networking/02-mapping-bad.swift
import Foundation

struct TransactionDTO: Decodable {
    let id: String
    let amount: String
    let currency: String
    let merchant_name: String?          // API naming leaks into the whole app
}

func configureCell(with dto: TransactionDTO) -> String {
    let amount = Double(dto.amount) ?? 0                       // bad data silently becomes 0, money as Double
    let text = String(format: "$%.2f", amount)                // "$" even for riel!
    return "\(dto.merchant_name ?? "")  \(text)"
}

let fromAPI = [
    TransactionDTO(id: "T1", amount: "-4.50", currency: "USD", merchant_name: "Coffee Shop"),
    TransactionDTO(id: "T2", amount: "-50000", currency: "KHR", merchant_name: "Lucky Market"),
    TransactionDTO(id: "T3", amount: "abc", currency: "USD", merchant_name: nil),
]

for dto in fromAPI {
    print(configureCell(with: dto))
}
print("→ riel shown as dollars, a broken amount shown as $0.00, and none of this is testable without a cell")
```

**Output**

```text
Coffee Shop  $-4.50
Lucky Market  $-50000.00
  $0.00
→ riel shown as dollars, a broken amount shown as $0.00, and none of this is testable without a cell
```
<!-- /example -->

### ✅ Good

<!-- example: examples/04-networking/02-mapping-good.swift -->
```swift
// ✅ GOOD: DTO (mirrors the API) → Domain (business rules) → ViewData (display-ready strings)
// Run: swift examples/04-networking/02-mapping-good.swift
import Foundation

// ── 1. DTO: exactly what the API sends ─────────────────────────────────────────────
struct TransactionDTO: Decodable, Sendable {
    let id: String
    let amount: String                  // "-4.50": money as a string, never Double
    let currency: String
    let bookedAt: Date
    let merchantName: String?
}

// ── 2. Domain: what the app reasons about ─────────────────────────────────────────
enum Currency: String, Sendable { case usd = "USD", khr = "KHR" }

struct Money: Hashable, Sendable {
    let amount: Decimal
    let currency: Currency

    func displayText(locale: Locale = .current) -> String {
        switch currency {
        case .usd: return amount.formatted(.currency(code: "USD").locale(locale))                      // -$4.50
        case .khr: return amount.formatted(.number.precision(.fractionLength(0)).locale(locale)) + " ៛"  // -50,000 ៛
        }
    }
}

struct Transaction: Sendable {
    let id: String
    let money: Money
    let date: Date
    let merchant: String
}

enum MappingError: Error {
    case invalidAmount(String)
    case unknownCurrency(String)
}

extension Transaction {
    init(dto: TransactionDTO) throws {
        guard let amount = Decimal(string: dto.amount) else { throw MappingError.invalidAmount(dto.amount) }
        guard let currency = Currency(rawValue: dto.currency) else { throw MappingError.unknownCurrency(dto.currency) }
        id = dto.id
        money = Money(amount: amount, currency: currency)
        date = dto.bookedAt
        merchant = dto.merchantName ?? "Unknown merchant"
    }
}

// ── 3. ViewData: only strings and flags; the cell just displays them ──────────────
struct TransactionRowViewData: Hashable, Sendable {
    let id: String
    let title: String
    let amountText: String
    let dateText: String
    let isDebit: Bool

    init(_ transaction: Transaction, locale: Locale = .current) {
        id = transaction.id
        title = transaction.merchant
        amountText = transaction.money.displayText(locale: locale)
        dateText = transaction.date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
        isDebit = transaction.money.amount < 0
    }
}

// ── Demo ───────────────────────────────────────────────────────────────────────────
let json = #"""
[
  {"id":"T1","amount":"-4.50","currency":"USD","booked_at":"2026-10-15T12:00:00Z","merchant_name":"Coffee Shop"},
  {"id":"T2","amount":"-50000","currency":"KHR","booked_at":"2026-10-15T12:00:00Z","merchant_name":"Lucky Market"},
  {"id":"T3","amount":"abc","currency":"USD","booked_at":"2026-10-16T12:00:00Z","merchant_name":null}
]
"""#

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase   // booked_at → bookedAt
decoder.dateDecodingStrategy = .iso8601

let locale = Locale(identifier: "en_US")              // fixed so the output matches; the app uses .current
let dtos = try decoder.decode([TransactionDTO].self, from: Data(json.utf8))

for dto in dtos {
    do {
        let row = TransactionRowViewData(try Transaction(dto: dto), locale: locale)
        let paddedTitle = row.title.padding(toLength: 14, withPad: " ", startingAt: 0)
        let paddedAmount = row.amountText.padding(toLength: 11, withPad: " ", startingAt: 0)
        print("\(row.isDebit ? "🔴" : "🟢") \(paddedTitle) \(paddedAmount) \(row.dateText)")
    } catch {
        print("⚠️ skipped \(dto.id): \(error) → report it to monitoring, don't show $0.00")
    }
}
```

**Output**

```text
🔴 Coffee Shop    -$4.50      Oct 15, 2026
🔴 Lucky Market   -50,000 ៛   Oct 15, 2026
⚠️ skipped T3: invalidAmount("abc") → report it to monitoring, don't show $0.00
```
<!-- /example -->

---

## 4.3 Caching and invalidation

| Layer | Tool |
|---|---|
| HTTP cache | `URLCache` (follows `Cache-Control` / `ETag`); **off** for sensitive data |
| In-memory cache | a dictionary inside an `actor`, or `NSCache` |
| Disk cache | a file, SQLite (GRDB), Core Data, SwiftData |
| Invalidation | TTL, after mutations (transfer), pull-to-refresh, logout |

**Why it matters:**
- **De-duplication:** three screens asking at launch should cause **one** request.
- **Invalidation:** after a transfer, the balance must refresh.
- **The trap:** a cache *without* de-duplication still fires many requests, because all callers miss the cache at the same time.

### ❌ Bad

<!-- example: examples/04-networking/03-caching-bad.swift -->
```swift
// ❌ BAD: a naive cache: no de-duplication, no expiry, no invalidation
// Run: swift examples/04-networking/03-caching-bad.swift

actor FakeAccountsAPI {
    private(set) var callCount = 0

    func fetchAccounts() async throws -> [String] {
        callCount += 1
        try await Task.sleep(for: .milliseconds(200))       // pretend this is the network
        return ["Savings USD: $1,250.50", "Current KHR: 50,000 ៛"]
    }
}

@MainActor
final class AccountRepository {
    private let api: FakeAccountsAPI
    private var cache: [String]?

    init(api: FakeAccountsAPI) { self.api = api }

    func accounts() async throws -> [String] {
        if let cache { return cache }
        let fresh = try await api.fetchAccounts()            // 3 screens can all get here at the same time
        cache = fresh
        return fresh
    }
    // ❌ no expiry: the balance can stay stale forever
    // ❌ no invalidate(): after a transfer the old balance is still shown
}

let api = FakeAccountsAPI()
let repository = AccountRepository(api: api)

// Home, Transfer and KHQR screens all load accounts at launch
async let home = repository.accounts()
async let transfer = repository.accounts()
async let khqr = repository.accounts()
_ = try await (home, transfer, khqr)
print("API calls at launch (3 screens):", await api.callCount)    // 3: the cache didn't help
```

**Output**

```text
API calls at launch (3 screens): 3
```
<!-- /example -->

### ✅ Good

<!-- example: examples/04-networking/03-caching-good.swift -->
```swift
// ✅ GOOD: an actor repository with TTL, request de-duplication and invalidation (a tiny React Query)
// Run: swift examples/04-networking/03-caching-good.swift

actor FakeAccountsAPI {
    private(set) var callCount = 0

    func fetchAccounts() async throws -> [String] {
        callCount += 1
        try await Task.sleep(for: .milliseconds(200))
        return ["Savings USD: $1,250.50", "Current KHR: 50,000 ៛"]
    }
}

actor AccountRepository {
    private let api: FakeAccountsAPI
    private let ttl: Duration
    private var cached: (value: [String], fetchedAt: ContinuousClock.Instant)?
    private var inFlight: Task<[String], Error>?

    init(api: FakeAccountsAPI, ttl: Duration = .seconds(60)) {
        self.api = api
        self.ttl = ttl
    }

    func accounts(forceRefresh: Bool = false) async throws -> [String] {
        if !forceRefresh, let cached, ContinuousClock.now - cached.fetchedAt < ttl {
            return cached.value                               // fresh cache hit
        }
        if let inFlight { return try await inFlight.value }  // someone is already fetching → share it

        let task = Task { try await api.fetchAccounts() }
        inFlight = task
        defer { inFlight = nil }

        let value = try await task.value
        cached = (value, ContinuousClock.now)
        return value
    }

    func invalidate() { cached = nil }                       // call after a transfer, and on logout
}

let api = FakeAccountsAPI()
let repository = AccountRepository(api: api)

async let home = repository.accounts()
async let transfer = repository.accounts()
async let khqr = repository.accounts()
_ = try await (home, transfer, khqr)
print("API calls at launch (3 screens):", await api.callCount)            // 1

_ = try await repository.accounts()
print("API calls after going back to Home:", await api.callCount)         // still 1 (cache hit)

await repository.invalidate()                                             // a transfer changed the balance
_ = try await repository.accounts()
print("API calls after a transfer + invalidate():", await api.callCount)  // 2
```

**Output**

```text
API calls at launch (3 screens): 1
API calls after going back to Home: 1
API calls after a transfer + invalidate(): 2
```
<!-- /example -->

**Stale-while-revalidate:** return the cached value immediately, then refresh in the background and publish the update.

---

## 4.4 Token refresh: the classic senior question

*"The access token expires while 5 requests are running. What happens?"*

**Why it matters:**
- **Token rotation:** most bank servers rotate refresh tokens, so each refresh **invalidates the previous token**.
- **The failure:** if every 401 triggers its own refresh, the requests cancel each other out and the user gets logged out.
- **The fix:** refresh **once**, make the others wait, then everyone retries with the new token.

### ❌ Bad

<!-- example: examples/04-networking/04-token-refresh-bad.swift -->
```swift
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
```

**Output** (numbers change on every run)

```text
✅ /profile
❌ /accounts: 401 again
❌ /cards: 401 again
❌ /notifications: 401 again
❌ /transactions: 401 again
refresh calls: 5 → each refresh killed the previous token
```
<!-- /example -->

### ✅ Good

<!-- example: examples/04-networking/04-token-refresh-good.swift -->
```swift
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
```

**Output**

```text
✅ /accounts
✅ /cards
✅ /notifications
✅ /profile
✅ /transactions
refresh calls: 1
```
<!-- /example -->

The same `TokenProvider` and `APIClient`, as a reusable module with unit tests, are in [`examples/06-architecture/BankKit`](../examples/06-architecture/BankKit).

**Practice**

- [ ] In `01-fetch-good.swift`, add a route that returns `401` and show "Session expired, please log in".
- [ ] In `02-mapping-good.swift`, add a `"EUR"` transaction. What does the user see? What should they see?
- [ ] In `03-caching-good.swift`, set `ttl: .milliseconds(100)`, sleep 200 ms, and confirm a second API call happens.
- [ ] In `04-token-refresh-good.swift`, make `refresh()` throw. What should the app do? (Answer: log out.)

---

## Alternatives and trade-offs

**HTTP client**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| `URLSession` + a small client (this guide) | no dependency (security reviews like that), full control, async/await | you write retry, auth refresh and multipart yourself | default for banking apps |
| Alamofire | interceptors (`RequestInterceptor` for token refresh), retry policies, `ServerTrustManager` pinning, multipart | large dependency to audit; abstraction over `URLSession` | the team already uses it, or many upload flows |
| Moya | API described as an enum on top of Alamofire; easy stubbing | more boilerplate, two dependencies | big REST APIs and a team that likes the pattern |
| swift-openapi-generator (Apple) | generates a type-safe client from an OpenAPI spec | needs an accurate spec; generated code to learn | the backend publishes OpenAPI |
| Apollo iOS / gRPC-Swift | GraphQL / protobuf clients with codegen | only if the backend uses them | GraphQL or gRPC backends |

**Caching and "React Query" behaviour**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| Actor repository (this guide) | exact control: TTL, dedupe, invalidation per feature | written per data type | default |
| `URLCache` + HTTP headers | free, follows server `Cache-Control` / `ETag` | the server must send good headers; stores responses on disk | public, non-sensitive data |
| Database as the source of truth (GRDB / Core Data) + observation | offline-first, survives restarts | more code, sync conflicts, sensitive data at rest | offline features (statements, history) |

**Images**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| Nuke | fast, prefetching, downsampling, modern Swift | dependency | image-heavy lists |
| Kingfisher | very popular, simple `imageView.kf.setImage` | dependency | quick integration |
| SDWebImage | oldest, many formats | Objective-C core | legacy projects |
| `URLSession` + `UIImage.byPreparingForDisplay()` | no dependency | you write caching and cancellation | a few logos and avatars |

---

[← Index](../README.md) · [← Concurrency](03-concurrency.md) · [Next: UIKit →](05-uikit.md)
