// ❌ BAD: Double for money → binary floating-point rounding errors
// Run: swift examples/02-swift/04-money-bad.swift

let fee = 0.1
let tax = 0.2
print("0.1 + 0.2 =", fee + tax)                 // 0.30000000000000004
print("equals 0.3?", fee + tax == 0.3)          // false 😱

var balance = 0.0
for _ in 0..<10 { balance += 0.1 }              // ten deposits of $0.10
print("balance after 10 × $0.10 =", balance)
print("can pay $1.00?", balance >= 1.0)         // false → "insufficient funds" bug
