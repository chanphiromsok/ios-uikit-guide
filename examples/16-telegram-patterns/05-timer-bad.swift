// ❌ BAD: a repeating timer whose handler holds `self` strongly → timer and screen keep each other alive.
//         The "Resend code" countdown keeps ticking after the user left, and the screen stays in memory
//         until the timer stops. A timer that never stops (e.g. balance polling) leaks the screen forever.
//         (Foundation's Timer.scheduledTimer(target: self, …) has the same problem: it retains its target.)
// Run: swift examples/16-telegram-patterns/05-timer-bad.swift
import Foundation

final class OTPViewController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.mybank.otp-timer")
    private var timer: DispatchSourceTimer?
    private var secondsLeft = 5

    func startCountdown() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.3, repeating: 0.3)          // 0.3 s stands in for 1 s
        timer.setEventHandler {
            self.tick()                                                 // ❌ strong self
        }
        timer.resume()
        self.timer = timer
    }

    private func tick() {
        secondsLeft -= 1
        print(secondsLeft > 0 ? "Resend code in \(secondsLeft)s" : "Resend enabled")
        if secondsLeft == 0 { timer?.cancel() }
    }

    deinit { print("OTPViewController freed") }
}

var screen: OTPViewController? = OTPViewController()
screen?.startCountdown()
Thread.sleep(forTimeInterval: 0.75)
screen = nil
print("— user left the OTP screen —")
Thread.sleep(forTimeInterval: 1.3)
print("…it kept ticking for a screen nobody sees, and was only freed when the countdown ended ❌")
