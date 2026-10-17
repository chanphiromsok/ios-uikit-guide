// 👀 EXPLORE: serial vs concurrent queues, sync vs async: watch the order of the prints
// Run: swift examples/15-gcd/01-queues-explore.swift
import Foundation

let serial = DispatchQueue(label: "com.mybank.serial")                                    // one job at a time, in order
let concurrent = DispatchQueue(label: "com.mybank.concurrent", attributes: .concurrent)  // many jobs at once

print("1. Serial queue: jobs run one after another, in the order you add them")
for job in 1...3 {
    serial.async { print("   serial job \(job)") }
}
serial.sync {}                                       // wait until the jobs above are done

print("2. Concurrent queue: jobs overlap, so the shortest one finishes first")
let group = DispatchGroup()
for (job, milliseconds) in [(1, 300), (2, 100), (3, 200)] {
    concurrent.async(group: group) {
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1000)   // pretend work
        print("   concurrent job \(job) finished after \(milliseconds) ms")
    }
}
group.wait()

print("3. async returns immediately; sync waits until the job has run")
serial.async {
    Thread.sleep(forTimeInterval: 0.05)
    print("   async job (ran later)")
}
print("   line after async")
serial.sync { print("   sync job") }
print("   line after sync")
