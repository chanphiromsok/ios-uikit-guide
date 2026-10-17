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
