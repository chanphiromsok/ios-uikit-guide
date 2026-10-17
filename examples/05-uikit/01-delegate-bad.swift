// ❌ BAD: a strong delegate → child and parent keep each other alive → memory leak
// Runs anywhere (no UIKit needed). The same rule applies to UITableView, UITextField, your own views…
// Run: swift examples/05-uikit/01-delegate-bad.swift

protocol AmountPickerDelegate: AnyObject {
    func amountPicker(didPick amount: Int)
}

final class AmountPicker {
    var delegate: (any AmountPickerDelegate)?          // ❌ strong reference back to the parent
    deinit { print("AmountPicker freed") }
}

final class TransferScreen: AmountPickerDelegate {
    let picker = AmountPicker()

    init() { picker.delegate = self }
    func amountPicker(didPick amount: Int) { print("picked $\(amount)") }
    deinit { print("TransferScreen freed ✅") }
}

var screen: TransferScreen? = TransferScreen()
screen?.picker.delegate?.amountPicker(didPick: 100)
screen = nil
print("Screen closed. Nothing was freed → leak 💧")
