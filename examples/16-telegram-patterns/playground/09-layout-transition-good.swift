// ✅ IDEA FROM TELEGRAM (`ContainedViewLayoutTransition` in submodules/Display): write ONE layout function and
//    pass it a transition: `.immediate` for first layout and rotation, `.animated` when the user taps.
//    Same code, no duplicated "animated" branch. Written from scratch for this guide; not Telegram's code.
// 🍎 Paste into an Xcode iOS Playground. Tap the card to expand and collapse it.
import UIKit
import PlaygroundSupport

@MainActor
enum LayoutTransition {
    case immediate
    case animated(duration: TimeInterval, curve: UIView.AnimationCurve = .easeInOut)

    func updateFrame(of view: UIView, to frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        // Never apply NaN or negative frames (a bad frame can corrupt Core Animation state)
        guard frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width.isFinite, frame.height.isFinite,
              frame.width >= 0, frame.height >= 0 else { return }
        guard view.frame != frame else {           // already there: no animation, no work
            completion?(true)
            return
        }
        perform({ view.frame = frame }, completion: completion)
    }

    func updateAlpha(of view: UIView, to alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        guard view.alpha != alpha else {
            completion?(true)
            return
        }
        perform({ view.alpha = alpha }, completion: completion)
    }

    private func perform(_ changes: @escaping () -> Void, completion: ((Bool) -> Void)?) {
        switch self {
        case .immediate:
            changes()
            completion?(true)
        case let .animated(duration, curve):
            // UIViewPropertyAnimator starts from what's on screen now, so a second tap mid-animation
            // smoothly reverses instead of jumping (Telegram's `beginWithCurrentState`)
            let animator = UIViewPropertyAnimator(duration: duration, curve: curve, animations: changes)
            animator.addCompletion { position in completion?(position == .end) }
            animator.startAnimation()
        }
    }
}

final class AccountCardViewController: UIViewController {
    private let card = UIView()
    private let balanceLabel = UILabel()
    private let detailsLabel = UILabel()
    private var isExpanded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        card.backgroundColor = .systemBlue
        card.layer.cornerRadius = 16
        card.clipsToBounds = true

        balanceLabel.text = "$1,250.50"
        balanceLabel.textColor = .white
        balanceLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)

        detailsLabel.text = "Account •••• 3456\nAvailable  $1,200.00\nOn hold      $50.50"
        detailsLabel.numberOfLines = 0
        detailsLabel.textColor = .white
        detailsLabel.alpha = 0

        view.addSubview(card)
        card.addSubview(balanceLabel)
        card.addSubview(detailsLabel)
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped)))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layout(size: view.bounds.size, transition: .immediate)        // first layout, rotation: no animation
    }

    @objc private func cardTapped() {
        isExpanded.toggle()
        layout(size: view.bounds.size, transition: .animated(duration: 0.35))   // same function, animated
    }

    /// The ONE place that knows where everything goes.
    private func layout(size: CGSize, transition: LayoutTransition) {
        let inset: CGFloat = 16
        let cardWidth = size.width - inset * 2
        let cardHeight: CGFloat = isExpanded ? 200 : 104

        transition.updateFrame(of: card, to: CGRect(x: inset, y: view.safeAreaInsets.top + inset,
                                                    width: cardWidth, height: cardHeight))
        balanceLabel.frame = CGRect(x: 20, y: 24, width: cardWidth - 40, height: 40)
        detailsLabel.frame = CGRect(x: 20, y: 76, width: cardWidth - 40, height: 100)
        transition.updateAlpha(of: detailsLabel, to: isExpanded ? 1 : 0)
    }
}

let viewController = AccountCardViewController()
viewController.preferredContentSize = CGSize(width: 390, height: 500)
PlaygroundPage.current.liveView = viewController
