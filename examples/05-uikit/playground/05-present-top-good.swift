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
