// ✅ IDEA FROM TELEGRAM (SwiftSignalKit `Timer`): a DispatchSource timer whose handler holds the owner WEAKLY,
//    and which cancels itself in deinit. Leaving the screen stops the countdown. Written from scratch.
// Run: swift examples/16-telegram-patterns/05-timer-good.swift
import Foundation

final class RepeatingTimer: @unchecked Sendable {
    private let source: DispatchSourceTimer

    init(interval: TimeInterval, queue: DispatchQueue, handler: @escaping @Sendable () -> Void) {
        source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + interval, repeating: interval)
        source.setEventHandler(handler: handler)
        source.resume()
    }

    func invalidate() { source.cancel() }

    deinit { source.cancel() }                                          // owner gone → timer stops
}

final class OTPViewController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.mybank.otp-timer")
    private var timer: RepeatingTimer?
    private var secondsLeft = 5

    func startCountdown() {
        timer = RepeatingTimer(interval: 0.3, queue: queue) { [weak self] in
            self?.tick()                                                // ✅ weak self
        }
    }

    private func tick() {
        secondsLeft -= 1
        print(secondsLeft > 0 ? "Resend code in \(secondsLeft)s" : "Resend enabled")
        if secondsLeft == 0 { timer?.invalidate() }
    }

    deinit { print("OTPViewController freed ✅ (its timer is cancelled too)") }
}

var screen: OTPViewController? = OTPViewController()
screen?.startCountdown()
Thread.sleep(forTimeInterval: 0.75)
screen = nil
print("— user left the OTP screen —")
Thread.sleep(forTimeInterval: 1.3)
print("…silence: nothing keeps running after the screen is gone")
