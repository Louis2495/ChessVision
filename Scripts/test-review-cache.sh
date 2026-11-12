#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cache_dir=$(mktemp -d)
trap 'rm -rf "$cache_dir"' EXIT
FEATURE_CHECK_SOURCE=Tests/Headless/ReviewCacheChecks.swift FEATURE_CHECK_BINARY=review-cache-checks bash Scripts/test-features.sh cold "$cache_dir"
"$PWD/.build/features/review-cache-checks" "$PWD" warm "$cache_dir"
"$PWD/.build/features/review-cache-checks" "$PWD" prefetch "$cache_dir"
