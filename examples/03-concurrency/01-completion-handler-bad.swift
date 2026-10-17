// ❌ BAD: classic GCD mistakes
//   1. completion is NOT called on the error path → the spinner spins forever
//   2. completion is called on a background thread → UI updated from the wrong thread
// Run: swift examples/03-concurrency/01-completion-handler-bad.swift
import Foundation

func fetchBalance(failing: Bool, completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().async {                    // pretend this is the network
        if failing {
            print("  [network] request failed… and nobody is told 🙈")
            return                                    // mistake 1: no completion
        }
        completion("$1,250.50")                       // mistake 2: still on a background thread
    }
}

print("Request 1 (success):")
fetchBalance(failing: false) { balance in
    print("  completion: \(balance) — on main thread? \(Thread.isMainThread)")
}
Thread.sleep(forTimeInterval: 0.3)

print("Request 2 (failure):")
fetchBalance(failing: true) { _ in
    print("  completion called")                      // never printed
}

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    print("1 second later: request 2 never called back → the spinner spins forever")
    exit(0)
}
dispatchMain()                                        // keep this script alive for GCD
