#!/usr/bin/env bash
set -euo pipefail

# Takes a fresh clone to a working state: checks the tools the other scripts assume and
# creates Config/Local.xcconfig from its example. Reports every problem, then exits non-zero
# if any was found.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
cd "$ROOT_DIR"

problems=0
note() { echo "  - $*"; problems=$((problems + 1)); }

echo "Tools"
if xcodebuild -version >/dev/null 2>&1; then
  echo "  ok   $(xcodebuild -version | head -1)"
else
  note "Xcode is missing. Install it from the App Store, then run xcode-select -s /Applications/Xcode.app"
fi
if command -v shellcheck >/dev/null; then
  echo "  ok   shellcheck $(shellcheck --version | sed -n 's/^version: //p')"
else
  note "shellcheck is missing (brew install shellcheck). make lint and make check need it."
fi

echo
echo "Config"
if [[ -f "$LOCAL_XCCONFIG" ]]; then
  echo "  ok   Config/Local.xcconfig"
else
  cp "$ROOT_DIR/Config/Local.example.xcconfig" "$LOCAL_XCCONFIG"
  echo "  new  Config/Local.xcconfig, copied from Local.example.xcconfig"
fi
team="$(xcconfig_value DEVELOPMENT_TEAM)"
if [[ -z "$team" || "$team" == "YOURTEAMID" ]]; then
  note "DEVELOPMENT_TEAM is not set in Config/Local.xcconfig. Debug macOS and Simulator builds work without it; Release builds, device runs, and make release need it."
fi
bundle_id="$(xcconfig_value APP_BUNDLE_ID)"
if [[ "$bundle_id" == com.example.* || "$bundle_id" == com.yourname.* ]]; then
  note "APP_BUNDLE_ID in Config/Local.xcconfig is still the placeholder: $bundle_id"
fi

echo
if ((problems > 0)); then
  echo "$problems item(s) need attention."
  exit 1
fi
echo "Ready. Next: make run, make test."
