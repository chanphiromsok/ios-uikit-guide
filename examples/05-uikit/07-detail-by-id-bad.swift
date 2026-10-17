// ❌ BAD: the detail screen has an OPTIONAL id that is set "sometime later", fetches even without it,
//         and never cancels, so when the id changes, an old slow response overwrites the new one
// Run: swift examples/05-uikit/07-detail-by-id-bad.swift
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
final class TransactionDetailViewController {           // imagine this is a UIViewController
    var transactionID: String?                           // ❌ optional, assigned after init (or forgotten)
    private(set) var screenText = ""
    private let api: FakeTransactionAPI

    init(api: FakeTransactionAPI) { self.api = api }

    func viewDidLoad() async {
        await load(id: transactionID ?? "")              // ❌ fetches even with no id
    }

    func show(id: String) {                              // iPad split view: the user taps another row
        transactionID = id
        Task { await load(id: id) }                      // ❌ the old request keeps running
    }

    private func load(id: String) async {
        do {
            let detail = try await api.detail(id: id)
            screenText = "\(detail.title) \(detail.amountText)"   // ❌ whoever finishes LAST wins
        } catch {
            screenText = "Something went wrong"
        }
    }
}

let api = FakeTransactionAPI()

// 1. The list pushes the screen but sets the id one line too late
let detail = TransactionDetailViewController(api: api)
await detail.viewDidLoad()
detail.transactionID = "T2"
print("1. requests sent:", await api.requestedIDs, "→ GET /v1/transactions/ (empty id!)")
print("   screen shows:", detail.screenText)

// 2. The user taps T1 (slow), then quickly T2 (fast)
detail.show(id: "T1")
detail.show(id: "T2")
try await Task.sleep(for: .milliseconds(500))
print("2. user selected T2, screen shows:", detail.screenText, "❌ (T1's slow response arrived last)")
