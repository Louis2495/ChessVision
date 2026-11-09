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
objects=()
for source in Engine/StockfishBridge.cpp Vendor/Stockfish/*.cpp Vendor/Stockfish/syzygy/tbprobe.cpp; do
    [[ "$source" == */main.cpp ]] && continue
    object="$build/objects/$(basename "${source%.cpp}").o"
    ${CXX:-c++} -std=c++14 -O2 -DNDEBUG -DIS_64BIT -DNO_PREFETCH -pthread -IEngine -IVendor/Stockfish -c "$source" -o "$object"
    objects+=("$object")
done
ar rcs "$build/libstockfish.a" "${objects[@]}"
printf '%s\n' 'import CStockfish' > "$build/EngineController.swift"
cat ChessVision/Engine/EngineController.swift >> "$build/EngineController.swift"
link_options=()
if [[ "$(uname -s)" == Linux ]]; then
    swiftc -emit-library -emit-module -module-name Combine Tests/Headless/CombineShim.swift -o "$build/libCombine.so" -emit-module-path "$build/Combine.swiftmodule"
    link_options=(-I "$build" -L "$build" -lCombine -Xlinker -rpath -Xlinker "$build" -Xlinker -lstdc++)
else
    link_options=(-Xlinker -lc++)
fi
swiftc -swift-version 5 -parse-as-library -I "$build/include" ChessVision/Core/*.swift "$build/EngineController.swift" Tests/Headless/ControllerChecks.swift "$build/libstockfish.a" "${link_options[@]}" -o "$build/controller-checks"
"$build/controller-checks"
