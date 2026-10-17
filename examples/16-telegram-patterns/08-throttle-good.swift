// ✅ IDEA FROM TELEGRAM (`Throttler`, simplified): leading-edge throttle: the first tap runs now, taps
//    inside the window are ignored. Telegram's version also replays the LAST value at the end of the window;
//    for "send an SMS" we deliberately don't. Written from scratch.
// Run: swift examples/16-telegram-patterns/08-throttle-good.swift
import Foundation

@MainActor
final class Throttler {
    private let interval: Duration
    private var lastRun: ContinuousClock.Instant?

    init(interval: Duration) { self.interval = interval }

    /// Runs `action` unless it already ran less than `interval` ago. Returns whether it ran.
    @discardableResult
    func run(_ action: () -> Void) -> Bool {
        let now = ContinuousClock.now
        if let lastRun, now - lastRun < interval { return false }
        lastRun = now
        action()
        return true
    }
}

@MainActor
final class OTPViewController {
    private let resendThrottle = Throttler(interval: .milliseconds(500))   // real app: 30–60 s, plus a server limit
    private var smsSent = 0

    func resendTapped(at time: String) {
        let sent = resendThrottle.run {
            smsSent += 1
            print("\(time): 📩 SMS #\(smsSent) sent")
        }
        if !sent { print("\(time): ignored (too soon)") }
    }
}

@MainActor
func demo() async throws {
    let screen = OTPViewController()
    let start = ContinuousClock.now
    for delay in [0, 100, 200, 700] {
        try await Task.sleep(until: start + .milliseconds(delay), clock: .continuous)
        screen.resendTapped(at: "\(delay) ms")
    }
}

try await demo()
