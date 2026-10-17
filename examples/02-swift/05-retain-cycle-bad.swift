// ❌ BAD: a closure captures self strongly → retain cycle → the screen is never freed (memory leak)
// Run: swift examples/02-swift/05-retain-cycle-bad.swift

final class TransferViewModel {
    var onSuccess: (() -> Void)?
}

final class TransferScreen {
    let viewModel = TransferViewModel()
    let title = "Transfer"

    init() {
        // screen → viewModel → closure → screen: a cycle
        viewModel.onSuccess = {
            print("Showing receipt on \(self.title)")
        }
        print("TransferScreen created")
    }

    deinit { print("TransferScreen freed ✅") }
}

var screen: TransferScreen? = TransferScreen()
screen = nil                                   // the user leaves the screen
print("Screen closed. Did you see \"freed\"? No → memory leak 💧")
