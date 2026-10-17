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
