// ❌ BAD: the screen starts requests and never keeps a handle on them → after the user leaves,
//         every request still downloads (data, battery, server load) for a screen nobody sees
// Run: swift examples/16-telegram-patterns/04-task-bag-bad.swift
import Foundation

@MainActor
final class Stats {
    static let shared = Stats()
    var finishedAfterLeaving = 0
    var cancelled = 0
}

@MainActor
final class HomeViewController {
    func viewDidLoad() {
        for item in ["balance", "cards", "offers"] {
            Task { [weak self] in                              // weak self avoids a leak…
                do {
                    try await Task.sleep(for: .seconds(1))     // pretend download
                    Stats.shared.finishedAfterLeaving += 1     // …but the work still happens
                    self?.render(item)
                } catch {
                    Stats.shared.cancelled += 1
                }
            }
        }
    }

    func render(_ item: String) { print("render \(item)") }
    deinit { print("HomeViewController freed") }
}

@MainActor
func demo() async throws {
    var screen: HomeViewController? = HomeViewController()
    screen?.viewDidLoad()
    try await Task.sleep(for: .milliseconds(200))
    screen = nil                                               // the user goes back after 0.2 s
    print("user left the screen")
    try await Task.sleep(for: .seconds(1.5))
    print("downloads finished after leaving: \(Stats.shared.finishedAfterLeaving), cancelled: \(Stats.shared.cancelled) ❌")
}

try await demo()
