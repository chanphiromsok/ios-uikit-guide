// ✅ GOOD: the id is REQUIRED by init, the list's summary shows instantly, the detail is fetched by id,
//          old requests are cancelled, and stale responses are ignored
// Run: swift examples/05-uikit/07-detail-by-id-good.swift
import Foundation

struct TransactionSummary: Equatable, Sendable {      // what the LIST screen already has
    let id: String
    let title: String
    let amountText: String
}

struct TransactionDetail: Equatable, Sendable {       // what the DETAIL endpoint returns
    let id: String
    let title: String
    let amountText: String
    let reference: String
    let status: String
}

struct NotFound: Error {}

// Fake API: GET /v1/transactions/{id}. T1 is slow, T2 is fast.
actor FakeTransactionAPI {
    private(set) var requestedIDs: [String] = []
    private let database = [
        "T1": TransactionDetail(id: "T1", title: "Lucky Market", amountText: "-50,000 ៛", reference: "FT2610150001", status: "Completed"),
        "T2": TransactionDetail(id: "T2", title: "Coffee Shop", amountText: "-$4.50", reference: "FT2610150002", status: "Completed"),
        "T3": TransactionDetail(id: "T3", title: "Salary", amountText: "+$900.00", reference: "FT2610010003", status: "Completed"),
    ]

    func detail(id: String) async throws -> TransactionDetail {
        requestedIDs.append(id)
        try await Task.sleep(for: .milliseconds(id == "T1" ? 300 : 100))
        guard let detail = database[id] else { throw NotFound() }
        return detail
    }
}

@MainActor
final class TransactionDetailViewModel {
    enum State: Equatable {
        case loading(summary: TransactionSummary?)       // show what we already know + a spinner
        case loaded(TransactionDetail)
        case failed(String)
    }

    private(set) var state: State
    private(set) var transactionID: String               // ✅ non-optional: no id → no screen
    private let api: FakeTransactionAPI
    private var loadTask: Task<Void, Never>?

    init(transactionID: String, summary: TransactionSummary? = nil, api: FakeTransactionAPI) {
        self.transactionID = transactionID
        self.state = .loading(summary: summary)
        self.api = api
    }

    /// Call from viewDidLoad.
    func load() {
        loadTask?.cancel()                               // ✅ stop any older request
        let id = transactionID
        loadTask = Task {
            do {
                let detail = try await api.detail(id: id)
                guard !Task.isCancelled, id == transactionID else { return }   // ✅ stale → ignore
                state = .loaded(detail)
            } catch is CancellationError {
                // the user left or picked another row: nothing to show
            } catch {
                state = .failed("Transaction not found")
            }
        }
    }

    /// iPad split view / "next transaction" button: same screen, new id.
    func show(transactionID newID: String, summary: TransactionSummary?) {
        transactionID = newID
        state = .loading(summary: summary)
        load()
    }

    /// Call when the user goes back (viewDidDisappear + isMovingFromParent).
    func cancel() { loadTask?.cancel() }

    func waitUntilLoaded() async { await loadTask?.value }   // only for this demo / tests
}

func describe(_ state: TransactionDetailViewModel.State) -> String {
    switch state {
    case .loading(let summary?): return "⏳ showing '\(summary.title) \(summary.amountText)' from the list + spinner"
    case .loading(nil):          return "⏳ spinner (no summary: opened from a link)"
    case .loaded(let detail):    return "✅ \(detail.title) \(detail.amountText) · ref \(detail.reference) · \(detail.status)"
    case .failed(let message):   return "⚠️ \(message)"
    }
}

let api = FakeTransactionAPI()

// 1. From the list: pass the id AND the summary the list already has
let summary = TransactionSummary(id: "T2", title: "Coffee Shop", amountText: "-$4.50")
let fromList = TransactionDetailViewModel(transactionID: summary.id, summary: summary, api: api)
print("1. from list, instantly:", describe(fromList.state))
fromList.load()
await fromList.waitUntilLoaded()
print("   after fetch:         ", describe(fromList.state))

// 2. From a push notification / deep link: only the id is known, and it may be missing
func transactionID(from link: String) -> String? {
    guard let url = URL(string: link), url.host == "transactions" else { return nil }
    let id = url.lastPathComponent
    return id.isEmpty || id == "/" ? nil : id
}

for link in ["mybank://transactions/T3", "mybank://transactions/"] {
    guard let id = transactionID(from: link) else {
        print("2. \(link) → no id → no API call, show 'Transaction not found'")   // like `enabled: !!id`
        continue
    }
    let fromLink = TransactionDetailViewModel(transactionID: id, api: api)
    print("2. \(link) →", describe(fromLink.state))
    fromLink.load()
    await fromLink.waitUntilLoaded()
    print("   after fetch:", describe(fromLink.state))
}

// 3. The user taps T1 (slow), then quickly T2 (fast) on the same screen
let splitView = TransactionDetailViewModel(transactionID: "T1", api: api)
splitView.load()
splitView.show(transactionID: "T2", summary: nil)
await splitView.waitUntilLoaded()
try await Task.sleep(for: .milliseconds(400))           // give T1's old response time to arrive (it won't count)
print("3. user selected T2, screen shows:", describe(splitView.state))

print("\nrequests sent:", await api.requestedIDs)
