#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
build="$root/.build/controller"
mkdir -p "$build/include" "$build/objects"
cp Engine/StockfishBridge.h "$build/include/StockfishBridge.h"
cat > "$build/include/module.modulemap" <<'MAP'
module CStockfish { header "StockfishBridge.h" export * }
MAP
library=$(bash Scripts/build-engine-library.sh)
modern=$(python3 Scripts/build-modern-engine.py)
printf '%s\n' 'import CStockfish' > "$build/EngineController.swift"
cat ChessVision/Engine/EngineController.swift >> "$build/EngineController.swift"
link_options=()
platform_options=()
if [[ "$(uname -s)" == Linux ]]; then
    swiftc -emit-library -emit-module -module-name Combine Tests/Headless/CombineShim.swift -o "$build/libCombine.so" -emit-module-path "$build/Combine.swiftmodule"
    link_options=(-I "$build" -L "$build" -lCombine -Xlinker -rpath -Xlinker "$build" -Xlinker -lstdc++)
else
    link_options=(-Xlinker -lc++)
    platform_options=(-target "$(uname -m)-apple-macosx13.0")
fi
swiftc -swift-version 5 "${platform_options[@]}" -parse-as-library -I "$build/include" ChessVision/Core/*.swift "$build/EngineController.swift" Tests/Headless/ControllerChecks.swift "$library" "$modern" "${link_options[@]}" -o "$build/controller-checks"
"$build/controller-checks"
