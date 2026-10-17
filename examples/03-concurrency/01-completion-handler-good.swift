// ✅ GOOD (GCD style): Result type, completion called EXACTLY once on every path, always on the main thread
// Run: swift examples/03-concurrency/01-completion-handler-good.swift
import Foundation

enum BalanceError: Error { case offline }

func fetchBalance(failing: Bool, delay: Double,
                  completion: @escaping @Sendable (Result<String, BalanceError>) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {     // pretend this is the network
        let result: Result<String, BalanceError> = failing ? .failure(.offline) : .success("$1,250.50")
        DispatchQueue.main.async { completion(result) }               // one exit point, main thread
    }
}

let group = DispatchGroup()

for (failing, delay) in [(false, 0.1), (true, 0.2)] {
    group.enter()
    fetchBalance(failing: failing, delay: delay) { result in
        dispatchPrecondition(condition: .onQueue(.main))   // stops in debug if we're NOT on the main queue
        switch result {
        case .success(let balance): print("✅ show \(balance) (on the main queue)")
        case .failure(let error):   print("⚠️ show error '\(error)' (on the main queue)")
        }
        group.leave()
    }
}

group.notify(queue: .main) {
    print("Both requests finished → hide the spinner")
    exit(0)
}
dispatchMain()                                        // keep this script alive for GCD
