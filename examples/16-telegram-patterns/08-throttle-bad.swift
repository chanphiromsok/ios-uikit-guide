// ❌ BAD: no protection against repeated taps → an impatient user triggers 4 OTP SMS in under a second
// Run: swift examples/16-telegram-patterns/08-throttle-bad.swift
import Foundation

@MainActor
final class OTPViewController {
    private var smsSent = 0

    func resendTapped(at time: String) {
        smsSent += 1
        print("\(time): 📩 SMS #\(smsSent) sent")                // ❌ every tap costs an SMS
    }
}

@MainActor
func demo() async throws {
    let screen = OTPViewController()
    let start = ContinuousClock.now
    for delay in [0, 100, 200, 700] {                           // taps at 0, 0.1, 0.2 and 0.7 s
        try await Task.sleep(until: start + .milliseconds(delay), clock: .continuous)
        screen.resendTapped(at: "\(delay) ms")
    }
}

try await demo()
