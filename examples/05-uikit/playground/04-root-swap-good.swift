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
