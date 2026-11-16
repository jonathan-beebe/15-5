#!/usr/bin/env bash
# Sourced by scripts/release-app.sh. Identifiers only, so this file is safe to commit.
# shellcheck disable=SC2034

# App Store Connect API key ID and issuer ID, from App Store Connect > Users and Access >
# Integrations > App Store Connect API. The key itself lives at
# ~/.appstoreconnect/private_keys/AuthKey_<API_KEY_ID>.p8, which is where xcodebuild and
# altool look for it. xcodebuild uses it to create and update provisioning profiles, and
# altool to validate and upload, so a release needs no Xcode account sign-in.
API_KEY_ID="9697G22SSX"
API_ISSUER_ID="ab5bed3a-b8bd-4895-987d-c7348680e036"
API_KEY_PATH="${API_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$API_KEY_ID.p8}"

# The signing team comes from DEVELOPMENT_TEAM in Config/Local.xcconfig. Both distribution
# certificates must be in the login keychain for that team:
#   Apple Distribution                  signs the apps        (security find-identity -v -p codesigning)
#   3rd Party Mac Developer Installer   signs the macOS .pkg  (security find-identity -v -p basic)
