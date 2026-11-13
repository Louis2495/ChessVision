#!/usr/bin/env bash
set -euo pipefail
FEATURE_CHECK_SOURCE=Tests/Headless/PlayLandingChecks.swift FEATURE_CHECK_BINARY=play-landing-checks bash "$(dirname "$0")/test-features.sh"
