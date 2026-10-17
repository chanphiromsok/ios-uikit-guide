// ✅ GOOD: `defer { group.leave() }` as the FIRST line → leave() runs exactly once on every path
// Run: swift examples/15-gcd/04-group-leave-good.swift
import Foundation

struct Offline: Error {}

func fetch(_ name: String, failing: Bool, completion: @escaping @Sendable (Result<String, any Error>) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + (failing ? 0.2 : 0.1)) {
        completion(failing ? .failure(Offline()) : .success(name))
    }
}

let group = DispatchGroup()
for (name, failing) in [("accounts", false), ("cards", true)] {
    group.enter()
    fetch(name, failing: failing) { result in
        defer { group.leave() }                                    // ✅ always
        switch result {
        case .success(let value): print("loaded \(value)")
        case .failure(let error): print("⚠️ \(name) failed (\(error)) → show a 'Try again' row")
        }
    }
}

group.notify(queue: .main) {
    print("everything finished → hide the spinner")
    exit(0)
}
dispatchMain()
