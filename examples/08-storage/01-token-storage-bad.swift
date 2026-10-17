// ❌ BAD: secrets in UserDefaults → a plain, unencrypted file inside the app's folder
// Run: swift examples/08-storage/01-token-storage-bad.swift
import Foundation

guard let defaults = UserDefaults(suiteName: "guide-demo-bad") else { fatalError("no defaults") }

defaults.set("eyJhbGciOiJIUzI1NiJ9.refresh-token", forKey: "refreshToken")   // ❌
defaults.set("1234", forKey: "pin")                                          // ❌❌

print("refreshToken:", defaults.string(forKey: "refreshToken") ?? "nil")
print("pin:", defaults.string(forKey: "pin") ?? "nil")
print("On iOS this is Library/Preferences/<bundle-id>.plist: readable in device backups and on jailbroken phones.")

defaults.removePersistentDomain(forName: "guide-demo-bad")                  // clean up this demo
