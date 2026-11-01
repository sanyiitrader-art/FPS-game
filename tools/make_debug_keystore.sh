#!/usr/bin/env bash
# Creates (or reuses) a throwaway TEST signing key and tells Godot to use it.
# This is NOT a production key: its password is public ("android") and it is never committed.
# Reusing the cached key keeps the app signature stable between builds so a new APK can
# be installed over the old one. If the cache is evicted a new key is made, and you must
# uninstall the previous test build first.
set -euo pipefail

KEYSTORE_DIR="${KEYSTORE_DIR:-$HOME/.quietfront}"
KEYSTORE="$KEYSTORE_DIR/debug.keystore"
ALIAS="androiddebugkey"
PASSWORD="android"

log() { printf '[make_debug_keystore] %s\n' "$*"; }

command -v keytool > /dev/null || { echo "keytool not found (run actions/setup-java first)" >&2; exit 1; }
mkdir -p "$KEYSTORE_DIR"

if [[ -s "$KEYSTORE" ]]; then
  log "reusing existing test key (signature stays the same as earlier builds)"
  status="Reused cached test key. New APKs can be installed over earlier builds."
else
  log "creating a new test key"
  keytool -genkeypair \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -storepass "$PASSWORD" \
    -keypass "$PASSWORD" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US"
  status="NEW test key created. If installing fails, uninstall the previous build first."
fi

fingerprint="$(keytool -list -keystore "$KEYSTORE" -storepass "$PASSWORD" 2> /dev/null | grep -i 'SHA' | head -n1 || true)"
log "$status"
log "fingerprint: ${fingerprint:-unknown}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Test signing key"
    echo
    echo "$status"
    echo
    echo "\`${fingerprint:-fingerprint unavailable}\`"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$KEYSTORE"
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=$ALIAS"
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=$PASSWORD"
    # Release-template builds are also signed with this test key (faster game, still test-signed).
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KEYSTORE"
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_USER=$ALIAS"
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$PASSWORD"
  } >> "$GITHUB_ENV"
fi