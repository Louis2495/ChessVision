#!/usr/bin/env bash
set -euo pipefail
FEATURE_CHECK_SOURCE=Tests/Headless/DeveloperChecks.swift FEATURE_CHECK_BINARY=developer-checks bash "$(dirname "$0")/test-features.sh"
