#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
sources=()
for source in Vendor/Stockfish/*.cpp; do
  [[ "$source" == */main.cpp ]] || sources+=("$source")
done
${CXX:-c++} -std=c++14 -O2 -DNDEBUG -DIS_64BIT -DNO_PREFETCH -pthread -IEngine -IVendor/Stockfish Engine/StockfishBridge.cpp Tests/engine_smoke.cpp "${sources[@]}" Vendor/Stockfish/syzygy/tbprobe.cpp -o .build/engine-smoke
.build/engine-smoke
