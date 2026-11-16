#!/usr/bin/env bash
set -euo pipefail

# Builds the macOS app and places the bundle at dist/15-5.app.
#
# Usage:
#   scripts/build-app.sh             # Debug, signed ad hoc, so it needs no team
#   scripts/build-app.sh --release   # Release, signed with the team in Config/Local.xcconfig

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
  build

mkdir -p "$DIST_DIR"
rm -rf "${DIST_DIR:?}"/*.app
ditto "$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app" "$DIST_DIR/$APP_NAME.app"
echo "Built dist/$APP_NAME.app ($CONFIGURATION)"
