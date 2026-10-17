// ✅ GOOD: a real UIKit list → detail flow. The detail screen requires the id, shows the list's summary
//          instantly, fetches the full detail by id, and cancels the request when the user goes back.
import UIKit
import PlaygroundSupport

struct TransactionSummary: Equatable, Sendable {
    let id: String
    let title: String
    let amountText: String
}

struct TransactionDetail: Equatable, Sendable {
    let id: String
    let title: String
    let amountText: String
    let reference: String
    let status: String
}

protocol TransactionDetailAPI: Sendable {
    func detail(id: String) async throws -> TransactionDetail
}

struct FakeTransactionAPI: TransactionDetailAPI {
    func detail(id: String) async throws -> TransactionDetail {
        print("GET /v1/transactions/\(id)")
        try await Task.sleep(for: .seconds(1.5))           // slow network so you can see the placeholder
        guard let summary = summaries.first(where: { $0.id == id }) else { throw URLError(.fileDoesNotExist) }
        return TransactionDetail(id: id, title: summary.title, amountText: summary.amountText,
                                 reference: "FT26101500\(id.dropFirst())", status: "Completed")
    }
}

let summaries = [
    TransactionSummary(id: "T1", title: "Lucky Market", amountText: "-50,000 ៛"),
    TransactionSummary(id: "T2", title: "Coffee Shop", amountText: "-$4.50"),
    TransactionSummary(id: "T3", title: "Salary", amountText: "+$900.00"),
]

// MARK: - ViewModel (no UIKit inside → unit-testable; same as examples/05-uikit/07-detail-by-id-good.swift)

@MainActor
final class TransactionDetailViewModel {
    enum State: Equatable {
        case loading(summary: TransactionSummary?)
        case loaded(TransactionDetail)
        case failed(String)
    }

    var onChange: (() -> Void)?
    private(set) var state: State { didSet { onChange?() } }
    private let transactionID: String
    private let api: any TransactionDetailAPI
    private var loadTask: Task<Void, Never>?

    init(transactionID: String, summary: TransactionSummary?, api: any TransactionDetailAPI) {
        self.transactionID = transactionID
        self.state = .loading(summary: summary)
        self.api = api
    }

    func load() {
        loadTask?.cancel()
        let id = transactionID
        loadTask = Task {
            do {
                let detail = try await api.detail(id: id)
                guard !Task.isCancelled else { return }
                state = .loaded(detail)
            } catch is CancellationError {
                print("request for \(id) cancelled ✅")
            } catch {
                state = .failed("Couldn't load this transaction")
            }
        }
    }

    func cancel() { loadTask?.cancel() }
}

// MARK: - Detail screen

final class TransactionDetailViewController: UIViewController {
    private let viewModel: TransactionDetailViewModel
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let referenceLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(viewModel: TransactionDetailViewModel) {         // ✅ can't be created without its data source
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transaction"
        view.backgroundColor = .systemBackground

        titleLabel.font = .preferredFont(forTextStyle: .title2)
        amountLabel.font = .preferredFont(forTextStyle: .largeTitle)
        referenceLabel.textColor = .secondaryLabel
        referenceLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, amountLabel, referenceLabel, spinner])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])

        viewModel.onChange = { [weak self] in self?.render() }
        render()
        viewModel.load()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent { viewModel.cancel() }      // ✅ user tapped Back → stop the request
    }

    private func render() {
        switch viewModel.state {
        case .loading(let summary):
            titleLabel.text = summary?.title ?? " "
            amountLabel.text = summary?.amountText ?? " "
            referenceLabel.text = "Loading details…"
            spinner.startAnimating()
        case .loaded(let detail):
            titleLabel.text = detail.title
            amountLabel.text = detail.amountText
            referenceLabel.text = "Reference: \(detail.reference)\nStatus: \(detail.status)"
            spinner.stopAnimating()
        case .failed(let message):
            referenceLabel.text = message
            spinner.stopAnimating()
        }
    }

    deinit { print("TransactionDetailViewController freed ✅") }
}

// MARK: - List screen

final class TransactionListViewController: UITableViewController {
    private let api: any TransactionDetailAPI = FakeTransactionAPI()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transactions"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        summaries.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.valueCell()
        content.text = summaries[indexPath.row].title
        content.secondaryText = summaries[indexPath.row].amountText
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let summary = summaries[indexPath.row]
        // ✅ pass the id (required) + the summary we already have (instant placeholder)
        let viewModel = TransactionDetailViewModel(transactionID: summary.id, summary: summary, api: api)
        navigationController?.pushViewController(TransactionDetailViewController(viewModel: viewModel), animated: true)
    }
}

let navigationController = UINavigationController(rootViewController: TransactionListViewController())
navigationController.preferredContentSize = CGSize(width: 390, height: 700)
PlaygroundPage.current.liveView = navigationController
// Tap a row: title + amount appear instantly, details 1.5 s later.
// Tap Back before 1.5 s: "request for T… cancelled ✅" and "TransactionDetailViewController freed ✅".
