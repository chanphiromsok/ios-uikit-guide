// ✅ GOOD: [weak self] breaks the cycle → the screen is freed when the user leaves
// Run: swift examples/02-swift/05-retain-cycle-good.swift

final class TransferViewModel {
    var onSuccess: (() -> Void)?
}

final class TransferScreen {
    let viewModel = TransferViewModel()
    let title = "Transfer"

    init() {
        viewModel.onSuccess = { [weak self] in
            guard let self else { return }      // the screen is already gone → do nothing
            print("Showing receipt on \(self.title)")
        }
        print("TransferScreen created")
    }

    deinit { print("TransferScreen freed ✅") }
}

var screen: TransferScreen? = TransferScreen()
screen?.viewModel.onSuccess?()                 // still works while the screen is alive
screen = nil                                   // the user leaves the screen
print("Screen closed.")
