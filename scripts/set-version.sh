#!/usr/bin/env bash
set -euo pipefail

# Writes the version and build number to Config/Base.xcconfig, the one place both platforms
# read them from, and with --commit-and-tag commits that file and tags HEAD vX.Y.Z+##.
# scripts/release-app.sh builds from that tag and refuses to run when the file and the tag
# disagree, so this script is the only writer.
#
# The build number defaults to the date and time (YYYYMMDDHHMM). App Store Connect refuses
# a build number at or below the last upload for that version, and a review rejection is
# fixed by a new build of the same version, so each cut needs a higher number. Minute
# granularity gives a same-day recut one.
#
# Usage:
#   scripts/set-version.sh X.Y.Z                      # build = date +%Y%m%d%H%M
#   scripts/set-version.sh X.Y.Z ##                   # explicit build number
#   scripts/set-version.sh X.Y.Z --commit-and-tag
#   scripts/set-version.sh X.Y.Z ## --commit-and-tag

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
cd "$ROOT_DIR"

USAGE="usage: $0 X.Y.Z [##] [--commit-and-tag]"
if [[ $# -lt 1 ]]; then
  echo "$USAGE" >&2
  exit 1
fi

VERSION="$1"
shift
if [[ $# -gt 0 && "$1" != --* ]]; then
  BUILD="$1"
  shift
else
  BUILD="$(date +%Y%m%d%H%M)"
fi

COMMIT_AND_TAG="false"
for arg in "$@"; do
  case "$arg" in
    --commit-and-tag) COMMIT_AND_TAG="true" ;;
    *) echo "error: unknown argument: $arg" >&2; echo "$USAGE" >&2; exit 1 ;;
  esac
done

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be X.Y.Z with no leading v, got \"$VERSION\"" >&2
  exit 1
fi
if [[ ! "$BUILD" =~ ^[0-9]+$ ]]; then
  echo "error: build must be a whole number, got \"$BUILD\"" >&2
  exit 1
fi
TAG="v$VERSION+$BUILD"

if [[ "$COMMIT_AND_TAG" == "true" ]]; then
  # Both guards run before any write, so a refusal leaves the tree as it was.
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "error: tag $TAG already exists" >&2
    exit 1
  fi
  if [[ -n "$(git diff --cached --name-only)" ]]; then
    echo "error: the index has staged changes, which the version commit would sweep in" >&2
    exit 1
  fi
fi

# Each write is read back, so a pattern that stopped matching fails here instead of tagging
# a build with the old number.
write_setting() {
  local name="$1" value="$2" old new
  old="$(xcconfig_value "$name")"
  sed -i '' -E "s/^([[:space:]]*${name}[[:space:]]*=).*$/\1 $value/" "$BASE_XCCONFIG"
  new="$(sed -nE "s/^[[:space:]]*${name}[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$BASE_XCCONFIG")"
  if [[ "$new" != "$value" ]]; then
    echo "error: Config/Base.xcconfig did not take $name = $value (reads \"$new\")" >&2
    exit 1
  fi
  echo "Config/Base.xcconfig: $name $old -> $new"
}

write_setting MARKETING_VERSION "$VERSION"
write_setting CURRENT_PROJECT_VERSION "$BUILD"

if [[ "$COMMIT_AND_TAG" == "true" ]]; then
  git commit -q -m "chore: version $VERSION build $BUILD" -- "$BASE_XCCONFIG"
  git tag "$TAG"
  echo "Committed and tagged $TAG. Next: make release-dry-run"
else
  cat <<MSG
Next:
  git commit -m "chore: version $VERSION build $BUILD" -- Config/Base.xcconfig
  git tag $TAG
  make release-dry-run
MSG
fi
