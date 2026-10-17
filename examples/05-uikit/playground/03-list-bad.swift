// ❌ BAD: cell reuse bug → scroll fast and rows show ANOTHER merchant's logo color
import UIKit
import PlaygroundSupport

struct Merchant {
    let name: String
    let colorName: String
    let color: UIColor
}

let palette: [(String, UIColor)] = [("red", .systemRed), ("green", .systemGreen), ("blue", .systemBlue),
                                    ("orange", .systemOrange), ("purple", .systemPurple)]
let merchants = (1...200).map { i in
    Merchant(name: "Merchant \(i)", colorName: palette[i % 5].0, color: palette[i % 5].1)
}

final class MerchantListViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        merchants.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let merchant = merchants[indexPath.row]
        cell.textLabel?.text = "\(merchant.name) · should be \(merchant.colorName)"

        // ❌ "Download" the logo. By the time it arrives, this cell may be showing a different row,
        //    and nothing resets the old image when the cell is reused.
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 0.3...1.5)))
            cell.imageView?.image = UIImage(systemName: "circle.fill")?
                .withTintColor(merchant.color, renderingMode: .alwaysOriginal)
            cell.setNeedsLayout()
        }
        return cell
    }
}

let viewController = MerchantListViewController()
viewController.preferredContentSize = CGSize(width: 390, height: 700)
PlaygroundPage.current.liveView = viewController
