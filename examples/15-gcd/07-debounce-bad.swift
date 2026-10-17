// ❌ BAD: every keystroke schedules its own search → 4 API calls for one word, results can arrive out of order
// Run: swift examples/15-gcd/07-debounce-bad.swift
import Foundation

@MainActor
final class SearchViewController {
    private var searchCount = 0

    func searchTextChanged(_ text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.search(text) }   // ❌ never cancelled
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
