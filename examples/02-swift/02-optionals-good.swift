// ✅ GOOD: unwrap safely with ??, guard let, if let and optional chaining
// Run: swift examples/02-swift/02-optionals-good.swift

struct User {
    let nickname: String?
}

// 1. ?? gives a default value
func greeting(for user: User) -> String {
    "Hello, \(user.nickname ?? "Guest")"
}

// 2. guard let exits early when the value is missing
func authorizationHeader(token: String?) -> String? {
    guard let token, !token.isEmpty else { return nil }
    return "Bearer \(token)"
}

print(greeting(for: User(nickname: nil)))                      // Hello, Guest
print(greeting(for: User(nickname: "Dara")))                   // Hello, Dara
print(authorizationHeader(token: nil) ?? "no token → show login")
print(authorizationHeader(token: "abc123") ?? "no token → show login")

// 3. if let runs code only when the value exists
let referralCode: String? = "SAVE10"
if let referralCode {
    print("Referral code applied:", referralCode)
}

// 4. Optional chaining: nil flows through instead of crashing
let nicknameLength = User(nickname: nil).nickname?.count
print("nickname length:", nicknameLength.map(String.init) ?? "nil")
