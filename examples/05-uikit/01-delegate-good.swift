// ✅ GOOD: `weak var delegate` → no cycle, both objects are freed
// Run: swift examples/05-uikit/01-delegate-good.swift

protocol AmountPickerDelegate: AnyObject {             // AnyObject → only classes → `weak` is allowed
    func amountPicker(didPick amount: Int)
}

final class AmountPicker {
    weak var delegate: (any AmountPickerDelegate)?     // ✅ weak
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
print("Screen closed.")
