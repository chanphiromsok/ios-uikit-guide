// ❌ BAD: blocking the MAIN thread with a semaphore to make async code "synchronous"
// Run: swift examples/15-gcd/05-semaphore-main-bad.swift
import Foundation

func fetchBalance(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
        DispatchQueue.main.async { completion("$1,250.50") }    // delivers on the main queue, as UI code should
    }
}

print("Home screen asks for the balance and waits…")
let semaphore = DispatchSemaphore(value: 0)
fetchBalance { balance in
    print("got \(balance)")                                       // never runs: main is blocked below
    semaphore.signal()
}

if semaphore.wait(timeout: .now() + 2) == .timedOut {            // real code often uses .distantFuture
    print("💀 2 s and nothing: main waits for the completion, the completion waits for main (deadlock)")
    print("   with no timeout the screen freezes; at launch, iOS's watchdog kills the app with crash code 0x8badf00d")
}
