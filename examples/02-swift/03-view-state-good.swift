// ✅ GOOD: one enum → exactly one state at a time, and the compiler forces you to handle every case
// Run: swift examples/02-swift/03-view-state-good.swift

enum ViewState<Value> {
    case loading
    case loaded(Value)
    case empty
    case failed(message: String)
}

func render(_ state: ViewState<[String]>) -> String {
    switch state {
    case .loading:              return "⏳ spinner"
    case .loaded(let accounts): return "📋 list: \(accounts.joined(separator: ", "))"
    case .empty:                return "🫙 \"No accounts yet\""
    case .failed(let message):  return "⚠️ \(message) [Try again]"
    }
}

let states: [ViewState<[String]>] = [
    .loading,
    .loaded(["Savings USD", "Current KHR"]),
    .empty,
    .failed(message: "Network error"),
]

for state in states {
    print(render(state))
}
