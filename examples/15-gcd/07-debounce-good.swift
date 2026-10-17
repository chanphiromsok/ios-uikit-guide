// ✅ GOOD: debounce with DispatchWorkItem: cancel the pending search on every keystroke
// Run: swift examples/15-gcd/07-debounce-good.swift
import Foundation

@MainActor
final class SearchViewController {
    private var pendingSearch: DispatchWorkItem?
    private var searchCount = 0

    func searchTextChanged(_ text: String) {
        pendingSearch?.cancel()                               // ✅ still typing → drop the old search
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.search(text) }   // the work item runs on the main queue
        }
        pendingSearch = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func search(_ text: String) {
        searchCount += 1
        print("🔎 API search #\(searchCount) for \"\(text)\"")
    }
}

DispatchQueue.main.async {                                          // UI code runs on the main queue
    let screen = SearchViewController()
    for (index, text) in ["c", "co", "cof", "coff"].enumerated() {  // the user types one letter every 100 ms
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) { screen.searchTextChanged(text) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        withExtendedLifetime(screen) { exit(0) }   // keep the screen alive, like a navigation stack would
    }
}
dispatchMain()
// async/await version: cancel a Task and use Task.sleep (see docs/14-uikit-components.md#uisearchcontroller)
