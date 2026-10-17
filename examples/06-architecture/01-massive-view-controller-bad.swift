// ❌ BAD: "Massive View Controller": networking, JSON parsing, formatting, business rules and navigation in one class
// Run: swift examples/06-architecture/01-massive-view-controller-bad.swift
import Foundation

@MainActor
final class AccountsViewController {                 // imagine this is a UIViewController
    var titleText = ""
    var rows: [String] = []

    func viewDidLoad() async {
        // 1. networking
        let json = await downloadJSON(from: "https://api.mybank.example/v1/accounts")
        // 2. parsing
        let objects = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [[String: Any]] ?? []
        // 3. formatting + business rules
        rows = objects.map { object in
            let balance = Double(object["balance"] as? String ?? "") ?? 0
            let warning = balance < 10 ? " ⚠️ low balance" : ""
            return "\(object["name"] as? String ?? "?"): $\(String(format: "%.2f", balance))\(warning)"
        }
        titleText = "\(rows.count) accounts"
        // 4. navigation
        if rows.isEmpty { print("→ push OpenAccountViewController") }
    }

    private func downloadJSON(from url: String) async -> String {
        print("  🌐 GET \(url)  (every test needs the real server)")
        return #"[{"name":"Savings","balance":"1250.5"},{"name":"Wallet","balance":"3.2"}]"#
    }
}

let viewController = AccountsViewController()
await viewController.viewDidLoad()
print(viewController.titleText)
viewController.rows.forEach { print("  \($0)") }
print("To test the 'low balance' rule you must run the whole screen and the network.")
