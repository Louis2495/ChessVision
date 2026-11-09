#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
library=$(bash Scripts/build-engine-library.sh)
${CXX:-c++} -std=c++17 -O2 -pthread -IEngine Tests/engine_smoke.cpp "$library" -o .build/engine-smoke
.build/engine-smoke
