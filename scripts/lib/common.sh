#!/usr/bin/env bash

# Shared names and helpers for scripts/. Sourced, never run. Each sourcing script uses a
# different subset of the names, so the unused-variable check is off for this file.
# shellcheck disable=SC2034

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT_DIR/15-5.xcodeproj"
SCHEME="15-5"
APP_NAME="15-5"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
LOG_DIR="$BUILD_DIR/logs"
DERIVED_DATA="$BUILD_DIR/DerivedData"
BASE_XCCONFIG="$ROOT_DIR/Config/Base.xcconfig"
LOCAL_XCCONFIG="$ROOT_DIR/Config/Local.xcconfig"

# Reads a `NAME = value` line from an xcconfig. Local overrides Base, as it does in the build.
xcconfig_value() {
  local name="$1" value="" file
  for file in "$LOCAL_XCCONFIG" "$BASE_XCCONFIG"; do
    [[ -f "$file" ]] || continue
    value="$(sed -nE "s/^[[:space:]]*${name}[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$file" | tail -1 | sed -E 's/[[:space:]]+$//')"
    [[ -n "$value" ]] && break
  done
  printf '%s' "$value"
}

# UDID of the Simulator to test on. SIMULATOR names a device, or is a UDID, or is unset for
# the first available iPhone. A name alone is ambiguous when two runtimes offer the same
# device, which is why the UDID is resolved here instead of passed to xcodebuild.
simulator_id() {
  local wanted="${SIMULATOR:-iPhone}" devices
  if [[ "$wanted" =~ ^[0-9A-F-]{36}$ ]]; then
    printf '%s' "$wanted"
    return
  fi
  devices="$(xcrun simctl list devices available | grep -F "$wanted" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')"
  if [[ -z "$devices" ]]; then
    echo "error: no available Simulator matches \"$wanted\" (xcrun simctl list devices available)" >&2
    return 1
  fi
  head -1 <<<"$devices"
}

# Runs xcodebuild with the full output in build/logs/<name>.log and only the lines that
# matter on the terminal: diagnostics, test results, and the final verdict. The exit status
# is xcodebuild's.
run_xcodebuild() {
  local name="$1"
  shift
  mkdir -p "$LOG_DIR"
  local log="$LOG_DIR/$name.log"
  echo "==> xcodebuild $* (log: ${log#"$ROOT_DIR"/})"
  set -o pipefail
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" "$@" 2>&1 \
    | tee "$log" \
    | { grep -E --line-buffered '(^|: )(error|warning):|✘|✔ Test run|\*\* [A-Z ]+ (SUCCEEDED|FAILED) \*\*' \
        | grep -vE 'appintentsmetadataprocessor|linkd.autoShortcut' || true; }
}
