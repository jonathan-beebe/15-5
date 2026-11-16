#!/usr/bin/env bash
set -euo pipefail

# Turns the tag on HEAD into App Store Connect uploads for macOS and iOS:
# preflight -> archive -> export -> validate -> upload, per platform.
#
# Preflight reports every problem at once, then stops before anything is built. A tree
# problem (no tag, version disagreement, uncommitted changes, no team) is fatal in both modes.
# A missing credential is fatal on a real run and a warning under --dry-run, where the steps
# that need it are reported as SKIPPED and the rest still run.
#
# Usage:
#   scripts/release-app.sh              # ends with the upload
#   scripts/release-app.sh --dry-run    # everything short of the upload

DRY_RUN="false"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="true" ;;
    *) echo "error: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/release-config.sh
source "$ROOT_DIR/scripts/release-config.sh"
cd "$ROOT_DIR"

# Xcode's export step runs rsync from PATH and fails with "Copy failed" under Homebrew's
# rsync. Everything this script calls is under /usr/bin.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

RELEASE_DIR="$BUILD_DIR/release"
FAILURES=()
CREDENTIAL_ISSUES=()
VALIDATION_FAILURES=()
HAVE_API_KEY="true"
TAG=""
VERSION=""
BUILD_NUMBER=""
TEAM_ID="$(xcconfig_value DEVELOPMENT_TEAM)"

fail() { FAILURES+=("$*"); }

check_tag() {
  if ! TAG="$(git describe --exact-match --tags HEAD 2>/dev/null)"; then
    TAG=""
    fail "HEAD has no tag. Run: make set-version VERSION=X.Y.Z TAG=1"
    return
  fi
  if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
    fail "tag \"$TAG\" is not vX.Y.Z+## (version + build number)"
    TAG=""
    return
  fi
  local body="${TAG#v}"
  VERSION="${body%%+*}"
  BUILD_NUMBER="${body##*+}"
}

check_version_agreement() {
  [[ -n "$TAG" ]] || return 0
  local file_version file_build
  file_version="$(xcconfig_value MARKETING_VERSION)"
  file_build="$(xcconfig_value CURRENT_PROJECT_VERSION)"
  if [[ "$file_version" != "$VERSION" || "$file_build" != "$BUILD_NUMBER" ]]; then
    fail "tag $TAG disagrees with Config/Base.xcconfig (MARKETING_VERSION=$file_version, CURRENT_PROJECT_VERSION=$file_build). scripts/set-version.sh $VERSION $BUILD_NUMBER writes both."
  fi
}

check_clean_tree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    fail "the working tree has uncommitted changes. A release is built from its tag alone."
  fi
}

check_team() {
  if [[ -z "$TEAM_ID" || "$TEAM_ID" == "YOURTEAMID" ]]; then
    fail "DEVELOPMENT_TEAM is not set in Config/Local.xcconfig"
  fi
}

check_config() {
  local var
  for var in API_KEY_ID API_ISSUER_ID; do
    if [[ -z "${!var:-}" || "${!var}" == "REPLACE_ME" ]]; then
      fail "scripts/release-config.sh: $var is unset"
    fi
  done
}

check_identities() {
  [[ -n "$TEAM_ID" ]] || return 0
  if ! security find-identity -v -p codesigning | grep -F "Apple Distribution:" | grep -qF "($TEAM_ID)"; then
    CREDENTIAL_ISSUES+=("no \"Apple Distribution\" certificate for team $TEAM_ID in the keychain")
  fi
  if ! security find-identity -v -p basic | grep -F "3rd Party Mac Developer Installer:" | grep -qF "($TEAM_ID)"; then
    CREDENTIAL_ISSUES+=("no \"3rd Party Mac Developer Installer\" certificate for team $TEAM_ID in the keychain")
  fi
}

check_api_key() {
  if [[ ! -f "$API_KEY_PATH" ]]; then
    CREDENTIAL_ISSUES+=("App Store Connect API key not found at $API_KEY_PATH")
    HAVE_API_KEY="false"
  fi
}

echo "15-5 release"
echo "============"
check_tag
check_version_agreement
check_clean_tree
check_team
check_config
check_identities
check_api_key

if ((${#FAILURES[@]} > 0)); then
  echo
  echo "Preflight failed:"
  for item in "${FAILURES[@]}"; do echo "  - $item"; done
  for item in "${CREDENTIAL_ISSUES[@]+"${CREDENTIAL_ISSUES[@]}"}"; do echo "  - $item"; done
  exit 1
fi
if ((${#CREDENTIAL_ISSUES[@]} > 0)); then
  echo
  if [[ "$DRY_RUN" != "true" ]]; then
    echo "Preflight failed:"
    for item in "${CREDENTIAL_ISSUES[@]}"; do echo "  - $item"; done
    exit 1
  fi
  echo "Preflight warnings (--dry-run continues, skipping the steps that need them):"
  for item in "${CREDENTIAL_ISSUES[@]}"; do echo "  - $item"; done
fi
echo
echo "Preflight OK: tag $TAG, version $VERSION, build $BUILD_NUMBER, team $TEAM_ID"

# With the API key, xcodebuild manages profiles through App Store Connect and needs no
# Xcode sign-in. Without it, under --dry-run, it falls back to the account in Xcode.
AUTH_ARGS=()
if [[ "$HAVE_API_KEY" == "true" ]]; then
  AUTH_ARGS=(-authenticationKeyPath "$API_KEY_PATH" -authenticationKeyID "$API_KEY_ID" -authenticationKeyIssuerID "$API_ISSUER_ID")
fi

rm -rf "${RELEASE_DIR:?}"
mkdir -p "$RELEASE_DIR" "$DIST_DIR"

# manageAppVersionAndBuildNumber is off: the tag sets the build number, and Xcode must not
# replace it. destination export writes the .pkg or .ipa for altool to validate and upload.
cat > "$RELEASE_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST

# $1 platform name for xcodebuild (macOS, iOS); $2 altool platform (macos, ios);
# $3 exported file extension (pkg, ipa).
release_platform() {
  local platform="$1" altool_platform="$2" extension="$3"
  local archive="$RELEASE_DIR/$APP_NAME-$platform.xcarchive"
  local export_dir="$RELEASE_DIR/export-$platform"
  local artifact="$DIST_DIR/$APP_NAME-$VERSION+$BUILD_NUMBER-$platform.$extension"
  local export_log="$LOG_DIR/release-export-$platform.log"

  echo
  echo "### $platform"
  run_xcodebuild "release-archive-$platform" \
    -destination "generic/platform=$platform" \
    -archivePath "$archive" \
    -derivedDataPath "$DERIVED_DATA-release" \
    -allowProvisioningUpdates "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
    archive

  echo "==> Export (log: ${export_log#"$ROOT_DIR"/})"
  if ! xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$RELEASE_DIR/ExportOptions.plist" \
    -exportPath "$export_dir" \
    -allowProvisioningUpdates "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
    >"$export_log" 2>&1; then
    echo "error: export failed" >&2
    grep -E 'error' "$export_log" | grep -v DVTDeveloperAccount | tail -10 >&2
    exit 1
  fi
  mv "$export_dir/$APP_NAME.$extension" "$artifact"
  echo "Exported ${artifact#"$ROOT_DIR"/}"

  if [[ "$HAVE_API_KEY" != "true" ]]; then
    echo "==> Validate: SKIPPED (no API key)"
    echo "==> Upload: SKIPPED (no API key)"
    return
  fi
  echo "==> Validate"
  if ! xcrun altool --validate-app -f "$artifact" -t "$altool_platform" --apiKey "$API_KEY_ID" --apiIssuer "$API_ISSUER_ID"; then
    # A real run stops here. A dry run goes on to the other platform, so one rehearsal
    # reports both, and fails at the end.
    [[ "$DRY_RUN" == "true" ]] || exit 1
    VALIDATION_FAILURES+=("$platform")
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "==> Upload: SKIPPED (--dry-run)"
    return
  fi
  echo "==> Upload"
  xcrun altool --upload-app -f "$artifact" -t "$altool_platform" --apiKey "$API_KEY_ID" --apiIssuer "$API_ISSUER_ID"
}

release_platform macOS macos pkg
release_platform iOS ios ipa

echo
if ((${#VALIDATION_FAILURES[@]} > 0)); then
  echo "Dry run built and exported both platforms. Validation failed for: ${VALIDATION_FAILURES[*]}. An \"Unable to find Apple ID for Bundle ID\" error means the app record is missing in App Store Connect."
  exit 1
elif [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run complete. Artifacts are in dist/. Run make release to upload."
else
  echo "Uploaded $TAG for both platforms. App Store Connect processes each build before it appears under TestFlight, and emails the account holder if processing rejects one."
fi
