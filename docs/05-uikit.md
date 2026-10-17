# 05 · UIKit fundamentals

[← Index](../README.md) · [← Networking and data](04-networking-and-data.md) · [Component catalog](14-uikit-components.md) · [Next: Architecture →](06-architecture.md)

Most examples here are 🍎 **Playground** files (they need Xcode). Delegates and list → detail logic are 🐧 and run anywhere.

> Looking for a specific component (UITextField, bottom sheets, UIMenu, DataScanner…)? See the **[UIKit component catalog](14-uikit-components.md)**.

| Topic | Bad | Good |
|---|---|---|
| [5.1 App structure](#51-app-structure-window-and-rootviewcontroller) | – | window → rootViewController |
| [5.2 Lifecycle](#52-view-controller-lifecycle) | 👀 explorer | – |
| [5.3 Auto Layout](#53-auto-layout) | hard-coded frames | constraints + stack + keyboard guide |
| [5.4 Lists](#54-lists-and-cell-reuse) | reuse bug | diffable + cancel in `prepareForReuse` |
| [5.5 Delegates](#55-delegates) | strong delegate | `weak var delegate` |
| [5.6 Login → Home](#56-login--home-swap-the-root) | push Home on Login | swap the root |
| [5.7 Presenting](#57-presenting-from-the-top) | present from root | present from top-most |
| [5.8 List → Detail](#58-list--detail-pass-the-id-fetch-by-id) | optional id, races | required id, cancel, ignore stale |

---

## 5.1 App structure: window and rootViewController

```
UIApplication.shared            ← global singleton
 └── UIWindowScene              (one per app window; iPad can have several)
      └── UIWindow              ← owns `rootViewController`
           └── rootViewController   e.g. UITabBarController
                ├── child VCs       (tabs, UINavigationController stacks)
                └── presentedViewController   (a modal on top, if any)
```

`rootViewController` is **not global**. It's a property of each `UIWindow`, like the `<App />` you mount into a React root. You set it in `SceneDelegate`:

```swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: LoginViewController())
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

**Inheritance vs `extension`:**
- **Inheritance:** `class DebugWindow: UIWindow` inherits everything (`rootViewController`, `frame`, `motionEnded`…). The chain is `DebugWindow → UIWindow → UIView → UIResponder → NSObject`.
- **Extension:** `extension UIWindow { }` adds methods to **every** `UIWindow`. Computed properties are allowed; stored properties are not.

**React → UIKit**

| React / React Native | UIKit |
|---|---|
| Component | `UIView` subclass |
| Screen | `UIViewController` |
| `<App />` in `#root` | `window.rootViewController` |
| `useEffect(() => …, [])` | `viewDidLoad()` |
| React Navigation stack | `UINavigationController` |
| FlatList | `UICollectionView` |
| Flexbox | Auto Layout / `UIStackView` |

---

## 5.2 View controller lifecycle

| Method | Runs | Use it for |
|---|---|---|
| `init(...)` | once | receive dependencies (ViewModel, ids) |
| `viewDidLoad()` | once | build subviews, constraints, bindings; first load |
| `viewWillAppear(_:)` | every time | refresh data if needed |
| `viewIsAppearing(_:)` | every time; size and traits known | UI that depends on size or traits |
| `viewDidLayoutSubviews()` | many times | cheap frame tweaks only |
| `viewDidAppear(_:)` | every time | start animations, analytics |
| `viewWillDisappear(_:)` | every time | hide sensitive data, save drafts |
| `viewDidDisappear(_:)` | every time | stop timers, cancel requests (`isMovingFromParent`) |
| `deinit` | when freed | proves there's no leak |

**Common mistakes:**
- Fetching in `viewWillAppear` with no cache. Every back-navigation becomes a network call.
- Heavy work in `viewDidLayoutSubviews`. It runs many times per second during rotation and animation.

### 👀 Explore (🍎 Playground)

<!-- playground: examples/05-uikit/playground/06-lifecycle-explorer.swift -->
```swift
// 👀 EXPLORE: watch the view controller lifecycle in the console while screens are pushed and popped
import UIKit
import PlaygroundSupport

class LoggingViewController: UIViewController {
    let name: String

    init(name: String) {
        self.name = name
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = name
        view.backgroundColor = .systemBackground
        print("\(name): viewDidLoad          ← once: build UI, start the first load")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("\(name): viewWillAppear       ← every time: refresh if needed")
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        print("\(name): viewIsAppearing      ← size and traits are known")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("\(name): viewDidAppear        ← start animations, analytics")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("\(name): viewWillDisappear    ← hide sensitive data, save drafts")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("\(name): viewDidDisappear     ← stop timers")
    }

    deinit { print("\(name): deinit               ← freed (no leak)") }
}

let navigationController = UINavigationController(rootViewController: LoggingViewController(name: "Home"))
navigationController.preferredContentSize = CGSize(width: 390, height: 700)
PlaygroundPage.current.liveView = navigationController

Task {
    try? await Task.sleep(for: .seconds(2))
    print("\n— push Transfer —")
    navigationController.pushViewController(LoggingViewController(name: "Transfer"), animated: true)
}

Task {
    try? await Task.sleep(for: .seconds(4))
    print("\n— pop Transfer —")
    navigationController.popViewController(animated: true)
}
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

---

## 5.3 Auto Layout

**Why it matters:**
- iPhones range from 320 to 440+ points wide, and the keyboard covers about 40% of the screen.
- Hard-coded frames look right on *your* simulator only.

| Concept | Meaning |
|---|---|
| Intrinsic content size | the natural size of a label or button from its content |
| Content hugging | "don't make me bigger than my content" |
| Compression resistance | "don't make me smaller than my content" (avoids truncation) |
| Ambiguous layout | not enough constraints (purple warning in the View Debugger) |
| Conflicting constraints | constraints that can't all be true (console log) |

**`frame` vs `bounds`:**
- `frame` is position and size in the **superview's** coordinates.
- `bounds` is in the view's **own** coordinates, with the origin usually (0, 0). A scroll view's `contentOffset` *is* its `bounds.origin`.

### ❌ Bad (🍎 Playground)

<!-- playground: examples/05-uikit/playground/02-autolayout-bad.swift -->
```swift
// ❌ BAD: hard-coded frames → right on one iPhone size only, button hidden under the keyboard
import UIKit
import PlaygroundSupport

final class LoginViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // 335 = 375 - 40: only correct on a 375-point-wide iPhone
        let phoneField = UITextField(frame: CGRect(x: 20, y: 100, width: 335, height: 44))
        phoneField.placeholder = "Phone number"
        phoneField.borderStyle = .roundedRect
        view.addSubview(phoneField)

        // y: 700 is off-screen on small phones and under the keyboard on all of them
        let loginButton = UIButton(type: .system)
        loginButton.frame = CGRect(x: 20, y: 700, width: 335, height: 50)
        loginButton.setTitle("Log in", for: .normal)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.backgroundColor = .systemBlue
        view.addSubview(loginButton)
    }
}

let viewController = LoginViewController()
viewController.preferredContentSize = CGSize(width: 320, height: 568)   // a small iPhone: the button is gone
PlaygroundPage.current.liveView = viewController
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

### ✅ Good (🍎 Playground)

<!-- playground: examples/05-uikit/playground/02-autolayout-good.swift -->
```swift
// ✅ GOOD: Auto Layout + UIStackView + keyboardLayoutGuide → adapts to every iPhone and the keyboard
import UIKit
import PlaygroundSupport

final class LoginViewController: UIViewController {
    private let phoneField = UITextField()
    private let pinField = UITextField()
    private let loginButton = UIButton(configuration: .filled())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        phoneField.placeholder = "Phone number"
        phoneField.keyboardType = .phonePad
        phoneField.textContentType = .telephoneNumber
        phoneField.borderStyle = .roundedRect

        pinField.placeholder = "PIN"
        pinField.keyboardType = .numberPad
        pinField.isSecureTextEntry = true
        pinField.borderStyle = .roundedRect

        loginButton.configuration?.title = "Log in"

        let fields = UIStackView(arrangedSubviews: [phoneField, pinField])
        fields.axis = .vertical
        fields.spacing = 12

        let views: [UIView] = [fields, loginButton]
        for subview in views {
            subview.translatesAutoresizingMaskIntoConstraints = false   // ALWAYS, for views you constrain
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            fields.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            fields.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            fields.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            phoneField.heightAnchor.constraint(equalToConstant: 44),
            pinField.heightAnchor.constraint(equalToConstant: 44),

            loginButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            // The button rides above the keyboard automatically:
            loginButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),
        ])
    }
}

let viewController = LoginViewController()
viewController.preferredContentSize = CGSize(width: 320, height: 568)   // try 430 × 932 too: still correct
PlaygroundPage.current.liveView = viewController
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

---

## 5.4 Lists and cell reuse

**Why it matters:**
- Like FlatList, iOS **reuses** cells while you scroll.
- If an old image download finishes after the cell was reused, the row shows the **wrong** logo. Fix it by cancelling and resetting in `prepareForReuse`.
- Use diffable data sources with item **identifiers**.

### ❌ Bad (🍎 Playground): scroll fast and watch the colors

<!-- playground: examples/05-uikit/playground/03-list-bad.swift -->
```swift
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
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

### ✅ Good (🍎 Playground)

<!-- playground: examples/05-uikit/playground/03-list-good.swift -->
```swift
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
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

---

## 5.5 Delegates

**Why it matters:**
- **The pattern:** a delegate is how a child talks back to its parent (`UITableViewDelegate`, `UITextFieldDelegate`, your own pickers).
- **The leak:** the parent already owns the child, so a **strong** delegate creates a retain cycle.

### ❌ Bad

<!-- example: examples/05-uikit/01-delegate-bad.swift -->
```swift
// ❌ BAD: a strong delegate → child and parent keep each other alive → memory leak
// Runs anywhere (no UIKit needed). The same rule applies to UITableView, UITextField, your own views…
// Run: swift examples/05-uikit/01-delegate-bad.swift

protocol AmountPickerDelegate: AnyObject {
    func amountPicker(didPick amount: Int)
}

final class AmountPicker {
    var delegate: (any AmountPickerDelegate)?          // ❌ strong reference back to the parent
    deinit { print("AmountPicker freed") }
}

final class TransferScreen: AmountPickerDelegate {
    let picker = AmountPicker()

    init() { picker.delegate = self }
    func amountPicker(didPick amount: Int) { print("picked $\(amount)") }
    deinit { print("TransferScreen freed ✅") }
}

var screen: TransferScreen? = TransferScreen()
screen?.picker.delegate?.amountPicker(didPick: 100)
screen = nil
print("Screen closed. Nothing was freed → leak 💧")
```

**Output**

```text
picked $100
Screen closed. Nothing was freed → leak 💧
```
<!-- /example -->

### ✅ Good

<!-- example: examples/05-uikit/01-delegate-good.swift -->
```swift
// ✅ GOOD: `weak var delegate` → no cycle, both objects are freed
// Run: swift examples/05-uikit/01-delegate-good.swift

protocol AmountPickerDelegate: AnyObject {             // AnyObject → only classes → `weak` is allowed
    func amountPicker(didPick amount: Int)
}

final class AmountPicker {
    weak var delegate: (any AmountPickerDelegate)?     // ✅ weak
    deinit { print("AmountPicker freed") }
}

final class TransferScreen: AmountPickerDelegate {
    let picker = AmountPicker()

    init() { picker.delegate = self }
    func amountPicker(didPick amount: Int) { print("picked $\(amount)") }
    deinit { print("TransferScreen freed ✅") }
}

var screen: TransferScreen? = TransferScreen()
screen?.picker.delegate?.amountPicker(didPick: 100)
screen = nil
print("Screen closed.")
```

**Output**

```text
picked $100
TransferScreen freed ✅
AmountPicker freed
Screen closed.
```
<!-- /example -->

---

## 5.6 Login → Home: swap the root

**Why it matters:**
- **No way back:** pushing Home on top of Login leaves a "< Login" back button.
- **Memory:** the login screen stays in memory.
- **Security on logout:** swapping the **whole root** removes every screen with balances from memory in one step. Interviewers ask this.

### ❌ Bad (🍎 Playground)

<!-- playground: examples/05-uikit/playground/04-root-swap-bad.swift -->
```swift
// ❌ BAD: pushing Home on top of Login → a "< Login" back button, and Login stays in memory
import UIKit
import PlaygroundSupport

final class LoginViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Login"
        view.backgroundColor = .systemBackground

        var config = UIButton.Configuration.filled()
        config.title = "Log in"
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(HomeViewController(), animated: true)   // ❌
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    deinit { print("LoginViewController freed") }
}

final class HomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home · $1,250.50"
        view.backgroundColor = .systemGreen.withAlphaComponent(0.2)
    }
}

let navigationController = UINavigationController(rootViewController: LoginViewController())
navigationController.preferredContentSize = CGSize(width: 390, height: 700)
PlaygroundPage.current.liveView = navigationController
// Tap "Log in": Home shows "< Login", the user can go back to the login form,
// and "LoginViewController freed" is never printed.
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

### ✅ Good (🍎 Playground)

<!-- playground: examples/05-uikit/playground/04-root-swap-good.swift -->
```swift
// ✅ GOOD: a coordinator swaps the whole root on login/logout → no way back, old screens are freed
import UIKit
import PlaygroundSupport

/// Holds exactly one child (Login flow or Home flow) and cross-fades between them.
/// In a real app you can also do `window.rootViewController = ...` from SceneDelegate.
final class RootViewController: UIViewController {
    private var current: UIViewController?

    func show(_ child: UIViewController) {
        let old = current
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve, animations: {
            old?.view.removeFromSuperview()
            self.view.addSubview(child.view)
        }, completion: { _ in
            old?.willMove(toParent: nil)
            old?.removeFromParent()
            child.didMove(toParent: self)
        })
        current = child
    }
}

final class LoginViewController: UIViewController {
    var onLoggedIn: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Login"
        view.backgroundColor = .systemBackground
        addCenteredButton(title: "Log in") { [weak self] in self?.onLoggedIn?() }
    }

    deinit { print("LoginViewController freed ✅") }
}

final class HomeViewController: UIViewController {
    var onLogout: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home · $1,250.50"
        view.backgroundColor = .systemGreen.withAlphaComponent(0.2)
        addCenteredButton(title: "Log out") { [weak self] in self?.onLogout?() }
    }

    deinit { print("HomeViewController freed ✅ (balances gone from memory)") }
}

extension UIViewController {
    func addCenteredButton(title: String, action: @escaping @MainActor () -> Void) {
        var config = UIButton.Configuration.filled()
        config.title = title
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

@MainActor
final class AppCoordinator {
    let root = RootViewController()

    func start() { showLogin() }

    private func showLogin() {
        let login = LoginViewController()
        login.onLoggedIn = { [weak self] in self?.showHome() }
        root.show(UINavigationController(rootViewController: login))
    }

    private func showHome() {
        let home = HomeViewController()
        home.onLogout = { [weak self] in
            // real app: delete the Keychain token and clear caches here first
            self?.showLogin()
        }
        root.show(UINavigationController(rootViewController: home))
    }
}

let coordinator = AppCoordinator()
coordinator.root.preferredContentSize = CGSize(width: 390, height: 700)
PlaygroundPage.current.liveView = coordinator.root
coordinator.start()
// Tap "Log in" → no back button, console prints "LoginViewController freed ✅".
// Tap "Log out" → "HomeViewController freed ✅".
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

---

## 5.7 Presenting from the top

**Why it matters:** a view controller can only present **one** modal at a time. A push-notification alert presented from the root while the Transfer sheet is open just doesn't appear.

### ❌ Bad (🍎 Playground)

<!-- playground: examples/05-uikit/playground/05-present-top-bad.swift -->
```swift
// ❌ BAD: presenting from the root while a modal is already open → nothing appears (only a console warning)
import UIKit
import PlaygroundSupport

let home = UIViewController()
home.title = "Home"
home.view.backgroundColor = .systemBackground
let navigationController = UINavigationController(rootViewController: home)
navigationController.preferredContentSize = CGSize(width: 390, height: 700)
PlaygroundPage.current.liveView = navigationController

// 1 s: the user opens the Transfer sheet
Task {
    try? await Task.sleep(for: .seconds(1))
    let transfer = UIViewController()
    transfer.view.backgroundColor = .systemYellow
    home.present(transfer, animated: true)
}

// 2.5 s: a push notification wants to show an alert
Task {
    try? await Task.sleep(for: .seconds(2.5))
    let alert = UIAlertController(title: "Money received", message: "+$20.00 from Dara", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    navigationController.present(alert, animated: true)   // ❌ root is already presenting the sheet
    // Console: "Attempt to present <UIAlertController…> on <UINavigationController…> which is already presenting…"
}
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

### ✅ Good (🍎 Playground)

<!-- playground: examples/05-uikit/playground/05-present-top-good.swift -->
```swift
// ✅ GOOD: always present from the top-most presented view controller
import UIKit
import PlaygroundSupport

extension UIViewController {
    /// Walks up the chain of modals: root → sheet → sheet-on-sheet…
    var topMostPresented: UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

let home = UIViewController()
home.title = "Home"
home.view.backgroundColor = .systemBackground
let navigationController = UINavigationController(rootViewController: home)
navigationController.preferredContentSize = CGSize(width: 390, height: 700)
PlaygroundPage.current.liveView = navigationController

Task {
    try? await Task.sleep(for: .seconds(1))
    let transfer = UIViewController()
    transfer.view.backgroundColor = .systemYellow
    home.present(transfer, animated: true)
}

Task {
    try? await Task.sleep(for: .seconds(2.5))
    let alert = UIAlertController(title: "Money received", message: "+$20.00 from Dara", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    navigationController.topMostPresented.present(alert, animated: true)   // ✅ shows on top of the sheet
}
// In an app: window.rootViewController?.topMostPresented.present(alert, animated: true)
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

---

## 5.8 List → Detail: pass the id, fetch by id

The detail screen gets an **id** from the list (or from a push notification or deep link) and fetches the full record by that id.

| React Native | UIKit |
|---|---|
| `navigation.navigate('Detail', { id })` | `TransactionDetailViewController(viewModel: .init(transactionID: id, …))` |
| `route.params.id` possibly `undefined` | **non-optional** `init(transactionID:)`: no id → the screen can't exist |
| `useQuery(['tx', id], …, { enabled: !!id })` | `guard let id else { show "not found"; return }` before any request |
| `placeholderData` from the list cache | pass the list's `summary` → show title and amount instantly |
| `AbortController` on unmount | `loadTask.cancel()` in `viewDidDisappear` when `isMovingFromParent` |
| race when `id` changes | cancel the old task + `guard id == transactionID` before updating state |

**Why it matters:**
- **An optional `id` set "later"** means requests like `GET /transactions/` with an empty id.
- **No cancellation** means that when the id changes quickly (iPad split view, "next" button), an **old slow response overwrites the new one**, and the user sees the wrong transaction.

### ❌ Bad

<!-- example: examples/05-uikit/07-detail-by-id-bad.swift -->
```swift
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
```

**Output**

```text
1. requests sent: [""] → GET /v1/transactions/ (empty id!)
   screen shows: Something went wrong
2. user selected T2, screen shows: Lucky Market -50,000 ៛ ❌ (T1's slow response arrived last)
```
<!-- /example -->

### ✅ Good

<!-- example: examples/05-uikit/07-detail-by-id-good.swift -->
```swift
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
```

**Output**

```text
1. from list, instantly: ⏳ showing 'Coffee Shop -$4.50' from the list + spinner
   after fetch:          ✅ Coffee Shop -$4.50 · ref FT2610150002 · Completed
2. mybank://transactions/T3 → ⏳ spinner (no summary: opened from a link)
   after fetch: ✅ Salary +$900.00 · ref FT2610010003 · Completed
2. mybank://transactions/ → no id → no API call, show 'Transaction not found'
3. user selected T2, screen shows: ✅ Coffee Shop -$4.50 · ref FT2610150002 · Completed

requests sent: ["T2", "T3", "T1", "T2"]
```
<!-- /example -->

### ✅ Good: the real UIKit screens (🍎 Playground)

<!-- playground: examples/05-uikit/playground/07-list-detail-good.swift -->
```swift
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
```

> 🍎 **Xcode only.** Xcode → File → New → Playground → iOS → Blank, paste everything, press ▶. Open the live view with **Editor → Live View** (⌥⌘↩).
<!-- /playground -->

**Practice**

- [ ] Build the Login screen from 5.3 with a "Show PIN" toggle.
- [ ] Add pull-to-refresh (`UIRefreshControl`) to the list in 5.4.
- [ ] In 5.6, add a confirmation alert before logging out (presented from the top-most VC).
- [ ] In 5.8, add a "Next transaction" button on the detail screen that calls `show(transactionID:summary:)`.

---

## Alternatives and trade-offs

**Layout**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| Auto Layout anchors in code (this guide) | built-in, no merge conflicts, adapts to every size | verbose | default in teams |
| SnapKit | short, readable constraint DSL | dependency; hides Auto Layout concepts from beginners | the team already uses it |
| Storyboards / XIBs | visual, quick prototypes | merge conflicts, runtime crashes from broken outlets, hard code review | solo prototypes, launch screens |
| Manual frames in `layoutSubviews` / PinLayout | fastest layout, predictable | you handle every size and Dynamic Type yourself | extremely heavy custom cells |
| FlexLayout (Yoga) | Flexbox like React Native | dependency, less common in iOS teams | RN-minded teams with complex flexible UIs |
| SwiftUI inside UIKit (`UIHostingController`) | fast to build, previews, declarative like React | mixing two UI systems; edge cases in navigation | new screens in a UIKit app |

**Lists**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| `UICollectionView` + diffable + compositional (this guide) | grids, carousels, lists, animations, modern API | more concepts up front | default for new screens |
| `UITableView` | simple, well known | single column; older patterns | simple settings screens, legacy code |
| IGListKit / Texture | diffing (IGListKit), async layout (Texture) | large dependencies, older | existing codebases only |

**Navigation and UI updates**

| Option | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| Coordinators by hand (this guide) | explicit, testable, no dependency | boilerplate | default |
| XCoordinator / routers | structured routes, deep-link friendly | dependency and framework rules | very large flows |
| Closures / delegates for updates | simple, no framework | wiring by hand | small screens |
| Combine `@Published` | operators, widely used | Combine knowledge needed | existing Combine code |
| `@Observable` + `updateProperties()` | automatic tracking, React-like | iOS 26 (iOS 18 with an Info.plist opt-in) | apps with a high minimum iOS version |

---

[← Index](../README.md) · [← Networking and data](04-networking-and-data.md) · [Component catalog](14-uikit-components.md) · [Next: Architecture →](06-architecture.md)
