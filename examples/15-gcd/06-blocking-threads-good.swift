//! output: varies
// ✅ GOOD: use non-blocking APIs (URLSession calls you back; no thread waits),
//          and cap truly blocking work with OperationQueue.maxConcurrentOperationCount
// Run: swift examples/15-gcd/06-blocking-threads-good.swift
import Foundation

// Counts how many jobs run at the same time (demo helper)
final class Peak: @unchecked Sendable {
    private let lock = NSLock()
    private var running = 0
    private var maximum = 0

    func start() { lock.lock(); running += 1; maximum = max(maximum, running); lock.unlock() }
    func finish() { lock.lock(); running -= 1; lock.unlock() }
    var peak: Int { lock.lock(); defer { lock.unlock() }; return maximum }
}

func seconds(_ duration: Duration) -> String {
    let value = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    return String(format: "%.1f", value)
}

// 1. Non-blocking: the "network" calls back later, like URLSession does
func fakeRequest(completion: @escaping @Sendable () -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2, execute: completion)
}

var start = ContinuousClock.now
let group = DispatchGroup()
for _ in 0..<100 {
    group.enter()
    fakeRequest { group.leave() }
}
group.wait()
print("100 non-blocking requests took \(seconds(ContinuousClock.now - start)) s")

// 2. Work that really blocks (e.g. an old SDK's synchronous upload): limit how many run at once
let uploads = OperationQueue()
uploads.maxConcurrentOperationCount = 2
let peak = Peak()
start = ContinuousClock.now
for _ in 1...6 {
    uploads.addOperation {
        peak.start()
        Thread.sleep(forTimeInterval: 0.2)        // pretend synchronous upload of one KYC page
        peak.finish()
    }
}
uploads.waitUntilAllOperationsAreFinished()
print("6 blocking uploads, at most \(peak.peak) at once, took \(seconds(ContinuousClock.now - start)) s")
