#!/usr/bin/env bash
set -euo pipefail
FEATURE_CHECK_SOURCE=Tests/Headless/DrawChecks.swift FEATURE_CHECK_BINARY=draw-checks bash "$(dirname "$0")/test-features.sh"
