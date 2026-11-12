#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo "Full Xcode on macOS is required." >&2; exit 1; }
swift test
if [[ -z "${SIMULATOR_ID:-}" ]]; then
  SIMULATOR_ID=$(xcrun simctl list devices available --json | python3 -c 'import json,sys; d=json.load(sys.stdin); ids=[x["udid"] for runtime,items in d["devices"].items() if "iOS" in runtime for x in items if x.get("isAvailable") and "iPhone" in x["name"]]; print(ids[0] if ids else "")')
fi
[[ -n "$SIMULATOR_ID" ]] || { echo "Install an iPhone Simulator runtime in Xcode Settings → Components." >&2; exit 1; }
mkdir -p .build
result_path=".build/NovaChess-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
xcodebuild test -project NovaChess.xcodeproj -scheme NovaChess -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath .build/DerivedData -resultBundlePath "$result_path" CODE_SIGNING_ALLOWED=NO
printf 'Test results: %s\n' "$result_path"
