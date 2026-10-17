// ❌ BAD: leave() is skipped on the error path → the group never finishes → the spinner never stops
// Run: swift examples/15-gcd/04-group-leave-bad.swift
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
        guard case .success(let value) = result else { return }   // ❌ returns without leave()
        print("loaded \(value)")
        group.leave()
    }
}

// (A script may wait. In an app, use group.notify(queue: .main) and never wait on the main thread.)
if group.wait(timeout: .now() + 2) == .timedOut {
    print("2 s later: still waiting for 'cards' → the home screen spinner never stops")
}
// Calling leave() MORE times than enter() is worse: the app crashes ("Unbalanced call to dispatch_group_leave()").
