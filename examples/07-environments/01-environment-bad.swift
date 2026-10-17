// ❌ BAD: switching environments by editing code, and a secret inside the app
// Run: swift examples/07-environments/01-environment-bad.swift

// let baseURL = "https://api.mybank.com"      // PROD
let baseURL = "https://api-dev.mybank.com"     // DEV  ← someone forgets to switch back before release
let apiKey = "sk_live_9f8e7d6c5b4a"            // ❌ anyone can extract strings from the app binary

print("Building for the App Store with base URL:", baseURL)
print("→ customers' app talks to the DEV server, and the 'secret' key ships to every phone")
