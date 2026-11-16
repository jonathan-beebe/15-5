#!/usr/bin/env bash
set -euo pipefail

# Builds the macOS app and places the bundle at dist/15-5.app.
#
# Usage:
#   scripts/build-app.sh             # Debug
#   scripts/build-app.sh --release   # Release
#
# Both sign with the team in Config/Local.xcconfig: the app group the widget shares with the
# app needs a development certificate on macOS. -allowProvisioningUpdates lets xcodebuild
# register the App IDs, the group, and this Mac the first time.

CONFIGURATION="Debug"
for arg in "$@"; do
  case "$arg" in
    --release) CONFIGURATION="Release" ;;
    *) echo "error: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
cd "$ROOT_DIR"

run_xcodebuild "build-macos-$CONFIGURATION" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build

mkdir -p "$DIST_DIR"
rm -rf "${DIST_DIR:?}"/*.app
ditto "$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app" "$DIST_DIR/$APP_NAME.app"
echo "Built dist/$APP_NAME.app ($CONFIGURATION)"
