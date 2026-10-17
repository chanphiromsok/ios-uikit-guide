//! mode: 5
//! output: varies
//! swift6-check
// ❌ BAD: many tasks change the same variable with no protection → lost updates (a data race)
// Run: swift examples/03-concurrency/04-shared-state-bad.swift

final class BalanceCounter {
    var value = 0
}

let counter = BalanceCounter()
await withTaskGroup(of: Void.self) { group in
    for _ in 0..<10_000 {
        group.addTask { counter.value += 1 }          // read → add → write, from many threads at once
    }
}
print("expected 10000, got \(counter.value)")
