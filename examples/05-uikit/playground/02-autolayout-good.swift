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
