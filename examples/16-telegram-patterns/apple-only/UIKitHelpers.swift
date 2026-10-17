// ✅ Small UIKit helpers inspired by Telegram's Display module (UIKitUtils.swift, HapticFeedback.swift,
//    GenerateImage.swift, KeyboardManager.swift). Written from scratch for this guide; not Telegram's code.
// 🍎 iOS only. Not run in this guide's Linux test.
import UIKit

// MARK: - Colors straight from the designer's hex values

extension UIColor {
    /// UIColor(rgb: 0x0A84FF)
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - Haptics: one cached generator per style, prepared before use

@MainActor
final class Haptics {
    static let shared = Haptics()

    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    /// Call when a haptic is about to happen (finger down on a PIN key) to cut latency.
    func prepareImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        impactGenerator(for: style).prepare()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        impactGenerator(for: style).impactOccurred()
    }

    func success() { notificationGenerator.notificationOccurred(.success) }   // transfer completed
    func error() { notificationGenerator.notificationOccurred(.error) }       // wrong PIN
    func selection() { selectionGenerator.selectionChanged() }                // picker / segmented change

    private func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let existing = impactGenerators[style] { return existing }
        let created = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style] = created
        return created
    }
}

// MARK: - Generated images: initials avatar for payees without a photo ("Sok Dara" → "SD")

func initialsAvatar(for name: String, diameter: CGFloat = 44, color: UIColor = UIColor(rgb: 0x0A84FF)) -> UIImage {
    let initials = name.split(separator: " ")
        .prefix(2)
        .compactMap(\.first)
        .map(String.init)
        .joined()
        .uppercased()
    let size = CGSize(width: diameter, height: diameter)

    return UIGraphicsImageRenderer(size: size).image { _ in
        color.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: diameter * 0.4, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
        let text = initials as NSString
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                  withAttributes: attributes)
    }
}

// MARK: - Dismiss the keyboard from anywhere

extension UIApplication {
    /// Sends `resignFirstResponder` up the responder chain: whichever field is editing gives up the keyboard,
    /// without needing a reference to it. (Telegram uses the same sendAction(to: nil) trick to FIND
    /// the first responder.)
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
