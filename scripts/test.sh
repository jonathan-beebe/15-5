#!/usr/bin/env bash
set -euo pipefail

# Runs the test suite. Both platforms by default, in sequence so the output stays readable.
#
# Usage:
#   scripts/test.sh            # macOS, then an iOS Simulator
#   scripts/test.sh --macos
#   scripts/test.sh --ios      # SIMULATOR=<name or UDID> picks the device; default is the first iPhone

RUN_MACOS="false"
RUN_IOS="false"
for arg in "$@"; do
  case "$arg" in
    --macos) RUN_MACOS="true" ;;
    --ios) RUN_IOS="true" ;;
    *) echo "error: unknown argument: $arg" >&2; exit 1 ;;
  esac
done
if [[ "$RUN_MACOS" == "false" && "$RUN_IOS" == "false" ]]; then
  RUN_MACOS="true"
  RUN_IOS="true"
fi

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
cd "$ROOT_DIR"

if [[ "$RUN_MACOS" == "true" ]]; then
  run_xcodebuild test-macos -destination 'platform=macOS' -derivedDataPath "$DERIVED_DATA" test
fi

if [[ "$RUN_IOS" == "true" ]]; then
  udid="$(simulator_id)"
  run_xcodebuild test-ios -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$DERIVED_DATA-ios" test
fi
