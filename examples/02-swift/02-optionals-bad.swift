//! expect: crash
// ❌ BAD: force unwrap (!) → the app crashes when the value is missing
// Run: swift examples/02-swift/02-optionals-bad.swift

struct User {
    let nickname: String?
}

let user = User(nickname: nil)     // the API didn't send a nickname
print("Opening home screen…")
print("Hello, \(user.nickname!)")  // 💥 crash
