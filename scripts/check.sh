#!/usr/bin/env bash
set -uo pipefail

# Every gate in one run: shell lint, tests on both platforms, and Release builds for both
# platforms. It runs all of them even after a failure, so one run reports everything, then
# exits non-zero if any gate failed.
#
# The Release builds here compile without signing, so a clone without a team can run them.
# make release is where signing is proven.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
cd "$ROOT_DIR" || exit 1

results=()
gate() {
  local name="$1"
  shift
  echo
  echo "### $name"
  if "$@"; then
    results+=("ok    $name")
  else
    results+=("FAIL  $name")
  fi
}

release_build() {
  local platform="$1"
  run_xcodebuild "check-release-$platform" \
    -configuration Release \
    -destination "generic/platform=$platform" \
    -derivedDataPath "$DERIVED_DATA-check" \
    CODE_SIGNING_ALLOWED=NO \
    build
}

gate "shellcheck" shellcheck -x scripts/*.sh scripts/lib/*.sh
gate "tests, macOS" scripts/test.sh --macos
gate "tests, iOS Simulator" scripts/test.sh --ios
gate "Release build, macOS" release_build macOS
gate "Release build, iOS" release_build iOS

echo
echo "Summary"
failed=0
for line in "${results[@]}"; do
  echo "  $line"
  [[ "$line" == FAIL* ]] && failed=$((failed + 1))
done
((failed == 0)) || exit 1
