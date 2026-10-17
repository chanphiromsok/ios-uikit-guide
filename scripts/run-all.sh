#!/usr/bin/env bash
# Runs every example that works without Xcode (🐧).
#   ./scripts/run-all.sh                 # all sections
#   ./scripts/run-all.sh 04-networking   # only files whose path contains "04-networking"
# Uses your local `swift` if installed, otherwise Docker (official swift image).
set -u
cd "$(dirname "$0")/.."

filter="${1:-}"
if command -v swift >/dev/null 2>&1; then
  run() { swift "$1"; }
else
  run() { docker run --rm -v "$PWD":/code -w /code swift:latest swift "$1"; }
fi

find examples -name '*.swift' \
  -not -path '*/playground/*' -not -path '*/apple-only/*' -not -path '*/BankKit/*' | sort |
while read -r file; do
  [[ -n "$filter" && "$file" != *"$filter"* ]] && continue
  echo "━━━ $file"
  run "$file"          # ❌ examples that crash on purpose will print a "Fatal error"
  echo
done
