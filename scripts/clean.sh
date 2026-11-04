#!/usr/bin/env bash
set -euo pipefail

# Removes what the builds produce: build/, dist/, and this project's entries in Xcode's
# DerivedData. Each path is named here. Config/Local.xcconfig and __local__/ are git-ignored
# too, and hold the team ID and local notes, so a `git clean -X` is the wrong tool.
#
# Usage:
#   scripts/clean.sh
#   scripts/clean.sh --dry-run   # list, delete nothing

DRY_RUN="false"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="true" ;;
    *) echo "error: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

remove() {
  local path="${1:?}"
  if [[ ! -e "$path" ]]; then
    echo "absent        $path"
    return
  fi
  local size
  size="$(du -sh "$path" 2>/dev/null | cut -f1)"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "would remove  $size  $path"
  else
    rm -rf "$path"
    echo "removed       $size  $path"
  fi
}

remove "${BUILD_DIR:?}"
remove "${DIST_DIR:?}"
for dir in "${HOME:?}/Library/Developer/Xcode/DerivedData/$APP_NAME-"*; do
  [[ -e "$dir" ]] && remove "$dir"
done
exit 0
