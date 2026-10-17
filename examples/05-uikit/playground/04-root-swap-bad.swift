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
