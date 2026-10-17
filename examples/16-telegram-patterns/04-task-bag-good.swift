// ✅ IDEA FROM TELEGRAM (`DisposableSet`): the screen owns a bag of jobs and cancels them all when it goes
//    away. Jobs added after the bag was cancelled are cancelled immediately. Written from scratch.
// Run: swift examples/16-telegram-patterns/04-task-bag-good.swift
import Foundation

final class TaskBag: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [Task<Void, Never>] = []
    private var isCancelled = false

    func add(_ task: Task<Void, Never>) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            task.cancel()                                      // too late: cancel right away
            return
        }
        tasks.append(task)
        lock.unlock()
    }

    func cancelAll() {
        lock.lock()
        let running = tasks
        tasks = []
        isCancelled = true
        lock.unlock()
        running.forEach { $0.cancel() }
    }

    deinit { tasks.forEach { $0.cancel() } }                   // owner gone → cancel everything
}

@MainActor
final class Stats {
    static let shared = Stats()
    var finishedAfterLeaving = 0
    var cancelled = 0
}

@MainActor
final class HomeViewController {
    private let bag = TaskBag()

    func viewDidLoad() {
        for item in ["balance", "cards", "offers"] {
            bag.add(Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(1))
                    Stats.shared.finishedAfterLeaving += 1
                    self?.render(item)
                } catch {
                    Stats.shared.cancelled += 1
                }
            })
        }
    }

    func render(_ item: String) { print("render \(item)") }
    deinit { print("HomeViewController freed → its TaskBag cancels 3 requests") }
}

@MainActor
func demo() async throws {
    var screen: HomeViewController? = HomeViewController()
    screen?.viewDidLoad()
    try await Task.sleep(for: .milliseconds(200))
    screen = nil
    print("user left the screen")
    try await Task.sleep(for: .seconds(1.5))
    print("downloads finished after leaving: \(Stats.shared.finishedAfterLeaving), cancelled: \(Stats.shared.cancelled) ✅")
}

try await demo()
