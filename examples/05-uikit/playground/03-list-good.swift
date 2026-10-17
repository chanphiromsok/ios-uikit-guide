// ✅ GOOD: UICollectionView list + diffable data source + cancel/reset in prepareForReuse
import UIKit
import PlaygroundSupport

struct Merchant: Identifiable {
    let id: Int
    let name: String
    let colorName: String
    let color: UIColor
}

let palette: [(String, UIColor)] = [("red", .systemRed), ("green", .systemGreen), ("blue", .systemBlue),
                                    ("orange", .systemOrange), ("purple", .systemPurple)]
let merchants = (1...200).map { i in
    Merchant(id: i, name: "Merchant \(i)", colorName: palette[i % 5].0, color: palette[i % 5].1)
}
let merchantsByID = Dictionary(uniqueKeysWithValues: merchants.map { ($0.id, $0) })

final class MerchantCell: UICollectionViewListCell {
    private var logoTask: Task<Void, Never>?

    func configure(with merchant: Merchant) {
        logoTask?.cancel()

        var placeholder = defaultContentConfiguration()
        placeholder.text = "\(merchant.name) · should be \(merchant.colorName)"
        placeholder.image = UIImage(systemName: "circle.dashed")
        contentConfiguration = placeholder

        let base = placeholder
        logoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double.random(in: 0.3...1.5)))   // pretend download
            guard !Task.isCancelled, let self else { return }                     // reused? → do nothing
            var loaded = base
            loaded.image = UIImage(systemName: "circle.fill")?
                .withTintColor(merchant.color, renderingMode: .alwaysOriginal)
            self.contentConfiguration = loaded
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        logoTask?.cancel()                                                       // ✅ stop the old download
        logoTask = nil
    }
}

final class MerchantListViewController: UIViewController {
    private enum Section { case main }
    private var dataSource: UICollectionViewDiffableDataSource<Section, Merchant.ID>!

    override func viewDidLoad() {
        super.viewDidLoad()

        let layout = UICollectionViewCompositionalLayout.list(using: UICollectionLayoutListConfiguration(appearance: .plain))
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)

        let registration = UICollectionView.CellRegistration<MerchantCell, Merchant.ID> { cell, _, id in
            if let merchant = merchantsByID[id] { cell.configure(with: merchant) }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Merchant.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(merchants.map(\.id))      // item identifiers, not whole models (Apple's recommendation)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

let viewController = MerchantListViewController()
viewController.preferredContentSize = CGSize(width: 390, height: 700)
PlaygroundPage.current.liveView = viewController
