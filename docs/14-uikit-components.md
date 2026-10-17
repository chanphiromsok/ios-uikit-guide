# 14 · UIKit component catalog

[← Index](../README.md) · [← UIKit fundamentals](05-uikit.md)

A reference of the UIKit (and system) components you'll use in a banking app. Each entry gives a **banking use case**, **tips and tricks**, **gotchas** and a short snippet.

> 🍎 Snippets are fragments that go inside a view controller (`viewDidLoad`, a delegate method…). They need Xcode and were **not compiled** in this guide's Linux test run. For complete runnable screens, see [05 · UIKit fundamentals](05-uikit.md).

## Index

| Category | Components |
|---|---|
| Text and input | [UILabel](#uilabel) · [UITextField](#uitextfield) · [UITextView](#uitextview) · [UISearchController](#uisearchcontroller) · [UIPasteControl](#uipastecontrol) |
| Buttons and controls | [UIButton](#uibutton) · [UISwitch](#uiswitch) · [UISegmentedControl](#uisegmentedcontrol) · [UISlider and UIStepper](#uislider-and-uistepper) · [UIDatePicker](#uidatepicker) · [UIPickerView](#uipickerview) |
| Images | [UIImageView and SF Symbols](#uiimageview-and-sf-symbols) · [QR code image](#qr-code-image-core-image) |
| Layout containers | [UIStackView](#uistackview) · [UIScrollView](#uiscrollview) · [Child view controllers](#child-view-controllers) |
| Lists and grids | [UITableView](#uitableview) · [UICollectionView](#uicollectionview) · [UIRefreshControl](#uirefreshcontrol) |
| Navigation | [UINavigationController](#uinavigationcontroller) · [UITabBarController](#uitabbarcontroller) · [UIPageViewController and UIPageControl](#uipageviewcontroller-and-uipagecontrol) |
| Presenting | [Bottom sheets](#bottom-sheets-uisheetpresentationcontroller) · [UIAlertController](#uialertcontroller) · [UIMenu and context menus](#uimenu-and-context-menus) · [UIActivityViewController](#uiactivityviewcontroller-share) |
| Feedback and status | [UIActivityIndicatorView and UIProgressView](#uiactivityindicatorview-and-uiprogressview) · [Empty and error states](#empty-and-error-states-uicontentunavailableconfiguration) · [Haptics](#haptics) · [UIVisualEffectView](#uivisualeffectview-blur) |
| System pickers and scanners | [PHPickerViewController](#phpickerviewcontroller-photos) · [UIDocumentPickerViewController](#uidocumentpickerviewcontroller-files) · [DataScannerViewController](#datascannerviewcontroller-khqr-scanning) |
| Web | [WKWebView and SFSafariViewController](#wkwebview-and-sfsafariviewcontroller) |
| Everywhere | [Tips for every screen](#tips-for-every-screen) |

---

## Text and input

### UILabel

**Use it for:** balances, names, transaction rows, any read-only text.

**Tips and tricks**
- **Dynamic Type:** `label.font = .preferredFont(forTextStyle: .body)` + `label.adjustsFontForContentSizeCategory = true`. For a custom or monospaced font, wrap it with `UIFontMetrics`.
- **Balances that update:** use **monospaced digits** so numbers don't jump left and right when they change.
- **Multi-line:** `numberOfLines = 0`.
- **Khmer:** stacked vowels and subscript consonants get clipped with tight line heights. Add line spacing and test with `-AppleLanguages (km)`.
- **VoiceOver:** give masked or formatted text a readable `accessibilityLabel`.

```swift
let balanceLabel = UILabel()
balanceLabel.font = UIFontMetrics(forTextStyle: .largeTitle)
    .scaledFont(for: .monospacedDigitSystemFont(ofSize: 34, weight: .bold))
balanceLabel.adjustsFontForContentSizeCategory = true
balanceLabel.text = "$1,250.50"

let accountLabel = UILabel()
accountLabel.text = "•••• 3456"
accountLabel.accessibilityLabel = "Account ending in 3 4 5 6"

// Khmer: extra line height so marks above/below aren't clipped
let style = NSMutableParagraphStyle()
style.lineHeightMultiple = 1.25
let khmerLabel = UILabel()
khmerLabel.numberOfLines = 0
khmerLabel.attributedText = NSAttributedString(
    string: "សមតុល្យគណនី",
    attributes: [.paragraphStyle: style, .font: UIFont.preferredFont(forTextStyle: .body)])
```

**Gotcha:** text truncated with "…"? Check `numberOfLines`, compression resistance, and whether a sibling with higher hugging priority is stealing the space.

### UITextField

**Use it for:** phone number, amount, account number, OTP, PIN.

**Tips and tricks**

| Field | `keyboardType` | `textContentType` | Extra |
|---|---|---|---|
| Phone | `.phonePad` | `.telephoneNumber` | normalize `+855` / `0` (see [12](12-interview-prep.md#live-coding-practice-)) |
| Amount (USD) | `.decimalPad` | – | max 2 decimals; use the locale's decimal separator |
| Amount (KHR) / account number | `.asciiCapableNumberPad` | – | forces 0–9 even with a Khmer keyboard |
| OTP from SMS | `.numberPad` | **`.oneTimeCode`** | iOS suggests the code above the keyboard |
| Password | default | `.password` / `.newPassword` | enables Keychain autofill |

- **Account numbers:** turn off `autocorrectionType`, `spellCheckingType` and `smartInsertDeleteType`.
- **Number pads have no Return key.** Add a "Done" toolbar, or pin the main button to `view.keyboardLayoutGuide` ([05 · 5.3](05-uikit.md#53-auto-layout)).

```swift
// Only digits and one decimal separator, max 2 decimals (UITextFieldDelegate)
func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
               replacementString string: String) -> Bool {
    let current = textField.text ?? ""
    guard let swiftRange = Range(range, in: current) else { return false }
    let updated = current.replacingCharacters(in: swiftRange, with: string)
    let separator = Locale.current.decimalSeparator ?? "."
    let parts = updated.components(separatedBy: separator)
    guard parts.count <= 2,
          parts.allSatisfy({ part in part.allSatisfy { "0123456789".contains($0) } }) else { return false }
    return parts.count == 1 || parts[1].count <= 2
}

// "Done" button above a number pad
let toolbar = UIToolbar()
toolbar.items = [.flexibleSpace(),
                 UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak amountField] _ in
                     amountField?.resignFirstResponder()
                 })]
toolbar.sizeToFit()
amountField.inputAccessoryView = toolbar
```

**Gotchas**
- `isSecureTextEntry` fields **clear their text** when the user starts typing again after leaving the field. That's expected iOS behaviour.
- Many banks use a **custom PIN pad** (buttons, no keyboard) so third-party keyboards never see the PIN ([09](09-security.md#94-privacy-cover-and-keyboards)).

### UITextView

**Use it for:** a transfer note or remark, terms and conditions, multi-line input.

**Tips and tricks**
- **Self-sizing:** inside a stack or scroll view, set `isScrollEnabled = false` so the view grows with its text.
- **No placeholder** is built in. Add a `UILabel` and hide it when there's text.
- **Read-only text:** `isEditable = false` + `dataDetectorTypes = [.link, .phoneNumber]`.
- **Length limit** (e.g. 100 characters): enforce it in `textView(_:shouldChangeTextIn:replacementText:)`.

### UISearchController

**Use it for:** searching transactions, payees or banks.

**Tips and tricks**
- **Attach it:** `navigationItem.searchController = searchController`, plus `navigationItem.hidesSearchBarWhenScrolling = false` if search is important.
- **Filtering in place:** `searchController.obscuresBackgroundDuringPresentation = false`.
- **Debounce** so you don't call the API on every keystroke:

```swift
// UISearchResultsUpdating
func updateSearchResults(for searchController: UISearchController) {
    searchTask?.cancel()
    let query = searchController.searchBar.text ?? ""
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))   // wait until the user stops typing
        guard !Task.isCancelled else { return }
        await viewModel.search(query)
    }
}
```

### UIPasteControl

**Use it for:** a "Paste" button next to the account-number field. It pastes **without** the "Allow Paste?" permission alert (iOS 16+).

```swift
let configuration = UIPasteControl.Configuration()
configuration.displayMode = .iconAndLabel
let pasteControl = UIPasteControl(configuration: configuration)
pasteControl.target = accountNumberField        // text fields accept pasted text
```

---

## Buttons and controls

### UIButton

**Use it for:** Transfer, Confirm, Pay, secondary actions, pull-down menus.

**Tips and tricks**
- **Styling:** use `UIButton.Configuration` (`.filled()`, `.tinted()`, `.gray()`, `.plain()`, `.borderedProminent()`) instead of setting colors by hand. It handles highlighted and disabled states and Dynamic Type.
- **While sending:** show a spinner **inside** the button and disable it. That prevents double transfers ([09 · 9.2](09-security.md#92-idempotent-transfers)).
- **Custom states:** `configurationUpdateHandler`.
- **Touch targets:** at least 44 × 44 points.

```swift
// in viewDidLoad
var config = UIButton.Configuration.filled()
config.title = "Confirm transfer"
config.cornerStyle = .large
let confirmButton = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
    self?.confirmTapped()
})

// while the request runs
confirmButton.isEnabled = false
confirmButton.configuration?.showsActivityIndicator = true
confirmButton.configuration?.title = "Sending…"
```

### UISwitch

**Use it for:** "Log in with Face ID", "Hide balance", notifications.

**Tips and tricks**
- **Observe changes:** `toggle.addAction(UIAction { … }, for: .valueChanged)`.
- **Turning on Face ID:** run the biometric check *first*. If it fails or is cancelled, flip the switch back with `setOn(false, animated: true)`.
- **Label:** the row's text goes in a separate `UILabel`. Set `accessibilityLabel` on the switch too.

### UISegmentedControl

**Use it for:** USD/KHR toggle; All / Income / Expense filter; chart ranges.

```swift
let currencyControl = UISegmentedControl(frame: .zero, actions: [
    UIAction(title: "USD") { [weak self] _ in self?.viewModel.select(.usd) },
    UIAction(title: "KHR") { [weak self] _ in self?.viewModel.select(.khr) },
])
currencyControl.selectedSegmentIndex = 0
```

**Gotcha:** Khmer titles are longer than English ones. Keep 2–4 short segments, and test in Khmer before shipping.

### UISlider and UIStepper

**Use them for:** a loan calculator (amount slider, term in months with a stepper).

**Tips and tricks**
- **Slider:** set `isContinuous = false` to recalculate only when the finger lifts. Snap values (`slider.value.rounded()`). Pair it with a text field for exact amounts.
- **Stepper:** set `minimumValue`, `maximumValue` and `stepValue`; `autorepeat` lets the user hold the button down.

### UIDatePicker

**Use it for:** statement date range, scheduled transfer date, date of birth in KYC.

**Tips and tricks**
- **Style:** `preferredDatePickerStyle = .compact` (a small button that opens a calendar), `.inline` (a full calendar) or `.wheels`.
- **Mode:** `datePickerMode = .date`.
- **Limits:** `maximumDate = .now` for statements; `minimumDate = .now` for scheduled transfers.
- **Calendar:** a user's device can be set to the Buddhist or Japanese calendar. For banking dates, set it explicitly: `datePicker.calendar = Calendar(identifier: .gregorian)`.

### UIPickerView

The classic spinning wheel. **Usually avoid it.** To choose an account or bank, use a `UIMenu` on a button (short lists) or a searchable list in a bottom sheet (long lists).

---

## Images

### UIImageView and SF Symbols

**Use it for:** bank and merchant logos, card art, icons, the "My QR" image.

**Tips and tricks**
- **Photos:** `contentMode = .scaleAspectFill` + `clipsToBounds = true`.
- **SF Symbols** scale with Dynamic Type when given a text style: `UIImage(systemName: "arrow.up.right", withConfiguration: UIImage.SymbolConfiguration(textStyle: .body))`.
- **Large images:** downsample them (`preparingThumbnail(of:)`) so they don't hit the memory and decode costs from [10](10-performance-and-rendering.md#1004-inside-the-commit-phase).
- **QR codes:** keep them sharp when scaled with `imageView.layer.magnificationFilter = .nearest`.

### QR code image (Core Image)

**Use it for:** the "My KHQR" receive-money screen. Generate the payload as shown in [12 · live coding](12-interview-prep.md#live-coding-practice-).

```swift
import CoreImage.CIFilterBuiltins

func qrImage(from payload: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(payload.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
          let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}
```

**Tip:** many bank apps raise screen brightness on the QR screen and restore it when leaving (`view.window?.windowScene?.screen.brightness`).

---

## Layout containers

### UIStackView

**Use it for:** forms, rows, cards. Most screens are stacks inside a scroll view.

**Tips and tricks**
- **Spacing:** `setCustomSpacing(24, after: headerView)` for one bigger gap.
- **Hiding:** set `isHidden` on an arranged subview and the stack collapses it. Do it inside `UIView.animate` to animate.
- **Padding:** `isLayoutMarginsRelativeArrangement = true` + `directionalLayoutMargins`.
- **Background:** `backgroundColor` works on stack views since iOS 14.

**Gotcha:** deeply nested stacks in every cell cost layout time while scrolling ([10](10-performance-and-rendering.md#1004-inside-the-commit-phase)).

### UIScrollView

**Use it for:** long forms (transfer, KYC) and detail screens.

**Tips and tricks**
- **The vertical-scroll trick:** pin the content to `contentLayoutGuide` on all four sides and set its width equal to `frameLayoutGuide`.
- **Keyboard:** pin the scroll view's bottom to `view.keyboardLayoutGuide.topAnchor` so it shrinks above the keyboard.
- **Dismissing the keyboard:** `keyboardDismissMode = .interactive` lets the user drag it away.

```swift
let scrollView = UIScrollView()
let content = UIStackView()
content.axis = .vertical
content.spacing = 12
content.isLayoutMarginsRelativeArrangement = true
content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

let views: [UIView] = [scrollView, content]
views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
view.addSubview(scrollView)
scrollView.addSubview(content)

NSLayoutConstraint.activate([
    scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
    scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

    content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
    content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
    content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
    content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
    content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),   // vertical only
])
scrollView.keyboardDismissMode = .interactive
```

### Child view controllers

**Use them for:** reusing a "balance card" screen inside several screens, or a root container that swaps Login and Home ([05 · 5.6](05-uikit.md#56-login--home-swap-the-root)).

```swift
addChild(child)
container.addSubview(child.view)
child.view.frame = container.bounds
child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
child.didMove(toParent: self)

// removing
child.willMove(toParent: nil)
child.view.removeFromSuperview()
child.removeFromParent()
```

**Gotcha:** skipping `addChild` / `didMove(toParent:)` breaks the child's lifecycle calls, rotation and trait updates.

---

## Lists and grids

### UITableView

**Use it for:** settings screens (`.insetGrouped` style), simple single-column lists, legacy code.

**Tips and tricks**
- **Self-sizing rows** work automatically when cell constraints are complete.
- **Deselecting:** call `tableView.deselectRow(at:animated:)` in `didSelectRowAt`.
- **Swipe actions**, e.g. removing a saved payee:

```swift
override func tableView(_ tableView: UITableView,
                        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
        self?.removePayee(at: indexPath)
        done(true)
    }
    return UISwipeActionsConfiguration(actions: [remove])
}
```

### UICollectionView

**Use it for:** almost every list or grid. Home screen sections, an account-card carousel, a quick-actions grid, the transaction list.

**Tips and tricks**
- **One collection view, several sections:** compositional layout lets you mix a carousel, a grid and a list on one screen.
- **Lists:** `UICollectionLayoutListConfiguration`, with swipe actions via `trailingSwipeActionsConfigurationProvider`.
- **Updating one cell** without flicker: diffable data source with ids ([05 · 5.4](05-uikit.md#54-lists-and-cell-reuse)) plus `snapshot.reconfigureItems([id])`.
- **Images:** `prefetchDataSource` starts downloads before cells appear.

```swift
// Account cards you swipe one by one
func accountsCarouselSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                        heightDimension: .fractionalHeight(1)))
    let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: .init(widthDimension: .fractionalWidth(0.85), heightDimension: .absolute(160)),
        subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.orthogonalScrollingBehavior = .groupPagingCentered
    section.interGroupSpacing = 12
    section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    return section
}
```

### UIRefreshControl

**Use it for:** pull-to-refresh on balances and transactions.

```swift
let refreshControl = UIRefreshControl()
refreshControl.addAction(UIAction { [weak self] _ in
    Task {
        await self?.viewModel.load(forceRefresh: true)
        self?.collectionView.refreshControl?.endRefreshing()     // ALWAYS end it, even after an error
    }
}, for: .valueChanged)
collectionView.refreshControl = refreshControl
```

---

## Navigation

### UINavigationController

**Use it for:** every stack of screens (Accounts → Transactions → Detail).

**Tips and tricks**
- **Large titles:** `navigationController?.navigationBar.prefersLargeTitles = true`, with `navigationItem.largeTitleDisplayMode = .never` on detail screens.
- **Back button:** `navigationItem.backButtonDisplayMode = .minimal` shows only the arrow.
- **Swipe-back:** keep it working. Don't hide the back button without a reason.
- **Colors:** set them through `UINavigationBarAppearance` (`standardAppearance` and `scrollEdgeAppearance`).
- **After a transfer succeeds, replace the stack** so Back from the receipt goes Home, not to the PIN screen:

```swift
navigationController?.setViewControllers([homeViewController, receiptViewController], animated: true)
```

### UITabBarController

**Use it for:** Home · Transfer · Scan · Cards · Account.

**Tips and tricks**
- **One stack per tab:** give each tab its **own** `UINavigationController`.
- **Badges:** `tabBarItem.badgeValue = "2"` for unread notifications.
- **A center "Scan" tab** that opens the scanner full screen instead of switching tabs:

```swift
// UITabBarControllerDelegate
func tabBarController(_ tabBarController: UITabBarController,
                      shouldSelect viewController: UIViewController) -> Bool {
    guard viewController is ScanPlaceholderViewController else { return true }
    tabBarController.present(ScannerViewController(), animated: true)
    return false
}
```

- **iOS 18+** adds the `UITab` API (and a new tab bar style on iPad). Check it if your minimum iOS version allows.

### UIPageViewController and UIPageControl

**Use them for:** onboarding pages and promo banners.

**Tips and tricks**
- **Simpler banners:** a compositional-layout section with `.groupPaging` plus a `UIPageControl` is often easier than a page view controller.
- **Auto-advancing banners:** `UIPageControlTimerProgress` (iOS 16+).

---

## Presenting

### Bottom sheets (UISheetPresentationController)

**Use them for:** choosing an account, a transfer summary before the PIN, filters.

```swift
let picker = AccountPickerViewController()
if let sheet = picker.sheetPresentationController {
    sheet.detents = [.medium(), .large()]
    sheet.prefersGrabberVisible = true
}
picker.isModalInPresentation = true      // block swipe-to-dismiss while a transfer is being sent
present(picker, animated: true)
```

**Tip:** custom heights with `.custom { _ in 280 }` (iOS 16+).

### UIAlertController

**Use it for:** confirmations ("Log out?"), blocking errors, and short choices as an action sheet.

**Tips and tricks**
- **Destructive actions** like Log out use `style: .destructive`.
- **Default action:** set `preferredAction` for the one Return triggers.
- **Don't alert for every error.** Inline errors and empty states are friendlier ([Empty and error states](#empty-and-error-states-uicontentunavailableconfiguration)).
- **Present from the top-most view controller** ([05 · 5.7](05-uikit.md#57-presenting-from-the-top)).

```swift
let sheet = UIAlertController(title: "Share receipt", message: nil, preferredStyle: .actionSheet)
sheet.addAction(UIAlertAction(title: "Save image", style: .default) { _ in /* … */ })
sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
sheet.popoverPresentationController?.sourceItem = shareButton   // REQUIRED on iPad, or it crashes
present(sheet, animated: true)
```

### UIMenu and context menus

**Use them for:** a "More" button (statement, freeze card) and long-press on a transaction (copy reference, share, report).

```swift
moreButton.menu = UIMenu(children: [
    UIAction(title: "Download statement", image: UIImage(systemName: "doc")) { _ in /* … */ },
    UIAction(title: "Freeze card", image: UIImage(systemName: "snowflake"), attributes: .destructive) { _ in /* … */ },
])
moreButton.showsMenuAsPrimaryAction = true     // opens on tap, not long-press

// Long-press menu on a collection view item (UICollectionViewDelegate, iOS 16+)
func collectionView(_ collectionView: UICollectionView,
                    contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                    point: CGPoint) -> UIContextMenuConfiguration? {
    guard let indexPath = indexPaths.first, let id = dataSource.itemIdentifier(for: indexPath) else { return nil }
    return UIContextMenuConfiguration(actionProvider: { _ in
        UIMenu(children: [
            UIAction(title: "Copy reference", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                self?.copyReference(for: id)
            },
        ])
    })
}
```

**Banking tip:** when copying sensitive values, make the clipboard item **local-only and expiring**:

```swift
UIPasteboard.general.setItems([[UTType.plainText.identifier: reference]],
                              options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
```

### UIActivityViewController (share)

**Use it for:** sharing a receipt image or PDF, or your "My KHQR" image.

```swift
let image = UIGraphicsImageRenderer(bounds: receiptView.bounds).image { _ in
    receiptView.drawHierarchy(in: receiptView.bounds, afterScreenUpdates: true)
}
let share = UIActivityViewController(activityItems: [image], applicationActivities: nil)
share.popoverPresentationController?.sourceItem = shareButton   // iPad
present(share, animated: true)
```

---

## Feedback and status

### UIActivityIndicatorView and UIProgressView

**Tips and tricks**
- **Prefer placeholders to full-screen spinners.** Show what you already know, as in the list → detail summary in [05 · 5.8](05-uikit.md#58-list--detail-pass-the-id-fetch-by-id).
- **Spinners inside buttons** come from the button configuration (`showsActivityIndicator`).
- **Upload progress:** bind a progress view directly to the upload task (KYC documents):
  `progressView.observedProgress = uploadTask.progress`.

### Empty and error states (UIContentUnavailableConfiguration)

**Use it for:** "No transactions yet", "You're offline [Try again]", loading screens (iOS 17+).

```swift
var config = UIContentUnavailableConfiguration.empty()
config.image = UIImage(systemName: "wifi.exclamationmark")
config.text = "You're offline"
config.secondaryText = "Check your connection and try again."
config.button = .tinted()
config.button.title = "Try again"
config.buttonProperties.primaryAction = UIAction { [weak self] _ in self?.reload() }
contentUnavailableConfiguration = config          // set back to nil when data arrives
```

### Haptics

**Use them for:** confirming success or failure without looking at the screen.

```swift
UINotificationFeedbackGenerator().notificationOccurred(.success)   // transfer completed
UINotificationFeedbackGenerator().notificationOccurred(.error)     // wrong PIN
UIImpactFeedbackGenerator(style: .light).impactOccurred()          // each PIN key tap
```

**Tip:** call `prepare()` on a generator just before you'll need it, for lower latency.

### UIVisualEffectView (blur)

**Use it for:** the app-switcher privacy cover ([09 · 9.4](09-security.md#94-privacy-cover-and-keyboards)) and frosted cards.

**Gotcha:** blur is one of the most expensive things for the render server. Avoid it inside scrolling cells ([10 · render hitches](10-performance-and-rendering.md#1005-frame-timing-and-hitches)).

---

## System pickers and scanners

### PHPickerViewController (photos)

**Use it for:** uploading an ID card or profile photo from the library for KYC. **No photo-library permission prompt needed.**

```swift
import PhotosUI

var configuration = PHPickerConfiguration()
configuration.filter = .images
configuration.selectionLimit = 1
let picker = PHPickerViewController(configuration: configuration)
picker.delegate = self                      // PHPickerViewControllerDelegate → load via itemProvider
present(picker, animated: true)
```

For taking a new photo, use the camera: `UIImagePickerController` with `sourceType = .camera`, or AVFoundation. That needs `NSCameraUsageDescription` in `Info.plist`.

### UIDocumentPickerViewController (files)

**Use it for:** uploading PDFs (payslips, statements).

```swift
import UniformTypeIdentifiers

let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
picker.delegate = self
present(picker, animated: true)
```

### DataScannerViewController (KHQR scanning)

**Use it for:** scan-to-pay. Validate the payload as shown in [12 · live coding](12-interview-prep.md#live-coding-practice-).

```swift
import VisionKit

guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
    // older device or camera denied → fall back to AVFoundation, or explain how to enable the camera
    return
}
let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                        isHighlightingEnabled: true)
scanner.delegate = self      // dataScanner(_:didAdd:allItems:) → case .barcode(let code): code.payloadStringValue
present(scanner, animated: true) {
    try? scanner.startScanning()
}
```

**Gotcha:** it needs iOS 16+, an A12 chip or newer, and `NSCameraUsageDescription`. Other options are compared in [12 · Alternatives](12-interview-prep.md#alternatives-and-trade-offs-khqr-scanning).

---

## Web

### WKWebView and SFSafariViewController

| | WKWebView | SFSafariViewController |
|---|---|---|
| Use it for | your own pages inside the app (FAQ, terms, promos) | links to **external** sites |
| App can read or modify the page | yes (JavaScript, navigation control) | no |
| User sees the real URL | only if you show it | yes, so it's more trustworthy |

**Tips and tricks**
- **Restrict navigation** to your own domains in `webView(_:decidePolicyFor:decisionHandler:)`.
- **Don't expose sensitive functions** to JavaScript through message handlers.
- **Don't keep cookies:** use `WKWebsiteDataStore.nonPersistent()` when nothing should be stored.
- **For OAuth or "link another bank" logins,** use `ASWebAuthenticationSession`, not a web view.

---

## Tips for every screen

- **Colors:** use semantic colors (`.label`, `.secondaryLabel`, `.systemBackground`) or asset-catalog colors with dark variants, and dark mode works automatically.
- **Dynamic Type:** test the largest accessibility text size with Environment Overrides ([11](11-devtools.md)).
- **Touch targets** of at least 44 × 44 points; `accessibilityLabel` for icons-only buttons.
- **Khmer:**
  - Use String Catalogs (`.xcstrings`) for translations.
  - Add extra line height.
  - Test with `-AppleLanguages (km)` and the Double-Length Pseudolanguage.
  - Don't put long Khmer text in fixed-width controls.
- **Spacing:** use `view.layoutMarginsGuide` and `safeAreaLayoutGuide` instead of hard-coded padding.

---

## Alternatives and trade-offs

| Approach | ✅ Strengths | ⚠️ Trade-offs | Pick it when |
|---|---|---|---|
| UIKit system components directly | free accessibility, Dynamic Type, dark mode; updated by Apple every iOS release | branding only through configuration and appearance APIs | default |
| Your own DesignSystem module wrapping them (`PrimaryButton`, `AmountLabel`, `MoneyField`) | consistent brand, one place to fix bugs and accessibility | upfront work | every bank app with a brand |
| Fully custom-drawn controls | pixel-perfect designs | you must rebuild accessibility, Dynamic Type and states yourself | rarely (a custom PIN pad is the common exception) |
| SwiftUI equivalents in `UIHostingController` | fast to build, previews | mixing two UI systems | new, self-contained screens |

---

[← Index](../README.md) · [← UIKit fundamentals](05-uikit.md)
