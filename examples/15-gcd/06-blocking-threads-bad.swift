//! output: varies
// ❌ BAD: blocking GCD threads while "waiting for the network"
// On iOS, GCD reacts by creating more and more threads (up to about 64): "thread explosion"
// → memory use, context switching, jank. Linux's GCD is more conservative, so here it's simply very slow.
// Run: swift examples/15-gcd/06-blocking-threads-bad.swift
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

let peak = Peak()
let group = DispatchGroup()
let start = ContinuousClock.now

for _ in 0..<100 {
    DispatchQueue.global().async(group: group) {
        peak.start()
        Thread.sleep(forTimeInterval: 0.2)          // ❌ a blocking "request": this thread can do nothing else
        peak.finish()
    }
}
group.wait()
print("100 blocking requests took \(seconds(ContinuousClock.now - start)) s, \(peak.peak) threads stuck waiting at once")
