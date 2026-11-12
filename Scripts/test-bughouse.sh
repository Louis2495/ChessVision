#!/usr/bin/env bash
set -euo pipefail
FEATURE_CHECK_SOURCE=Tests/Headless/BughouseWaitingChecks.swift FEATURE_CHECK_BINARY=bughouse-waiting-checks bash "$(dirname "$0")/test-features.sh"
