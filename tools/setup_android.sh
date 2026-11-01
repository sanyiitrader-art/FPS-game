#!/usr/bin/env bash
# Installs the Android SDK packages Godot needs to export APKs.
# Installs into $ANDROID_SDK_ROOT (cached between runs); skips whatever is already there.
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-35.0.1}"
PLATFORM="${ANDROID_PLATFORM:-android-35}"
NDK_VERSION="${ANDROID_NDK_VERSION:-28.1.13356709}"
CMAKE_VERSION="${ANDROID_CMAKE_VERSION:-3.10.2.4988404}"
INSTALL_NDK="${INSTALL_NDK:-1}"
CMDLINE_URL="${ANDROID_CMDLINE_URL:-https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip}"

SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"

log() { printf '[setup_android] %s\n' "$*"; }
die() { printf '[setup_android] ERROR: %s\n' "$*" >&2; exit 1; }

command -v java > /dev/null || die "java not found (run actions/setup-java first)"
mkdir -p "$ANDROID_SDK_ROOT"

# Bootstrap the command-line tools if this is a fresh SDK directory.
if [[ ! -x "$SDKMANAGER" ]]; then
  log "downloading Android command-line tools"
  tmp="$(mktemp -d)"
  curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 -o "$tmp/cmdline-tools.zip" "$CMDLINE_URL"
  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp/unzipped"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mv "$tmp/unzipped/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -rf "$tmp"
fi
[[ -x "$SDKMANAGER" ]] || die "sdkmanager not found at $SDKMANAGER"

# Work out which packages are still missing.
missing=()
[[ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]] || missing+=("platform-tools")
[[ -d "$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS" ]] || missing+=("build-tools;$BUILD_TOOLS")
[[ -d "$ANDROID_SDK_ROOT/platforms/$PLATFORM" ]] || missing+=("platforms;$PLATFORM")
if [[ "$INSTALL_NDK" == "1" ]]; then
  [[ -d "$ANDROID_SDK_ROOT/cmake/$CMAKE_VERSION" ]] || missing+=("cmake;$CMAKE_VERSION")
  [[ -d "$ANDROID_SDK_ROOT/ndk/$NDK_VERSION" ]] || missing+=("ndk;$NDK_VERSION")
fi

if [[ ${#missing[@]} -gt 0 ]]; then
  log "accepting licenses"
  set +o pipefail
  yes | "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" --licenses > /dev/null 2>&1 || true
  set -o pipefail
  log "installing: ${missing[*]}"
  "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" --install "${missing[@]}"
else
  log "all required packages already present (cache hit)"
fi

# Final verification.
[[ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]] || die "platform-tools missing after install"
[[ -d "$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS" ]] || die "build-tools $BUILD_TOOLS missing after install"
[[ -d "$ANDROID_SDK_ROOT/platforms/$PLATFORM" ]] || die "platform $PLATFORM missing after install"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "ANDROID_HOME=$ANDROID_SDK_ROOT" >> "$GITHUB_ENV"
  echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" >> "$GITHUB_ENV"
fi
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$ANDROID_SDK_ROOT/platform-tools" >> "$GITHUB_PATH"
fi

du -sh "$ANDROID_SDK_ROOT" || true
df -h / | tail -n 1
log "done"