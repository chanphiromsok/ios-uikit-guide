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
