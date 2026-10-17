// ❌ BAD: several flags that can contradict each other
// Run: swift examples/02-swift/03-view-state-bad.swift

struct AccountsScreenState {
    var isLoading = false
    var errorMessage: String?
    var accounts: [String] = []
}

var state = AccountsScreenState()
state.isLoading = true
state.accounts = ["Savings USD"]       // old data from the last load
state.errorMessage = "Network error"   // the refresh failed… and we forgot isLoading = false

// Spinner, error, or list? All three say "show me".
print("isLoading:", state.isLoading)
print("errorMessage:", state.errorMessage ?? "-")
print("accounts:", state.accounts)
print("→ the screen shows a spinner AND an error AND a list 🤯")
