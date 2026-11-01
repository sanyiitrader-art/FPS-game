#!/usr/bin/env bash
# Installs a pinned Godot editor and the Android export templates for headless CI use.
# Everything is cached in $GODOT_CACHE_DIR so later runs skip the large downloads.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.6.3}"
GODOT_RELEASE="${GODOT_RELEASE:-stable}"
CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/godot-cache}"

TAG="${GODOT_VERSION}-${GODOT_RELEASE}"
ENGINE_ZIP="Godot_v${TAG}_linux.x86_64.zip"
TEMPLATES_TPZ="Godot_v${TAG}_export_templates.tpz"
SUMS_FILE="SHA512-SUMS.txt"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}"
BIN="$CACHE_DIR/godot"
STAMP="$CACHE_DIR/installed-${TAG}.stamp"

BASE_URLS=(
  "https://github.com/godotengine/godot-builds/releases/download/${TAG}"
  "https://github.com/godotengine/godot/releases/download/${TAG}"
)

: "${JAVA_HOME:?JAVA_HOME is not set (run actions/setup-java first)}"
: "${ANDROID_SDK_ROOT:?ANDROID_SDK_ROOT is not set (run tools/setup_android.sh first)}"

log() { printf '[setup_godot] %s\n' "$*"; }
die() { printf '[setup_godot] ERROR: %s\n' "$*" >&2; exit 1; }

# download <file> <destination-dir>: tries each mirror until one works.
download() {
  local file="$1" dest="$2" base
  for base in "${BASE_URLS[@]}"; do
    if curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 -o "$dest/$file" "$base/$file"; then
      return 0
    fi
  done
  return 1
}

# verify <file> <dir>: checks the SHA-512 against the official sums file.
verify() {
  local file="$1" dir="$2" expected actual
  if [[ ! -s "$dir/$SUMS_FILE" ]]; then
    if [[ "${ALLOW_UNVERIFIED:-0}" == "1" ]]; then
      log "WARNING: no checksum file, skipping verification of $file"
      return 0
    fi
    die "checksum file $SUMS_FILE could not be downloaded; refusing unverified $file"
  fi
  expected="$(awk -v f="$file" '$2==f || $2=="*" f {print $1}' "$dir/$SUMS_FILE" | head -n1)"
  [[ -n "$expected" ]] || die "no checksum entry for $file"
  actual="$(sha512sum "$dir/$file" | awk '{print $1}')"
  [[ "$expected" == "$actual" ]] || die "checksum mismatch for $file"
  log "checksum OK: $file"
}

mkdir -p "$CACHE_DIR" "$TEMPLATE_DIR"

if [[ ! -f "$STAMP" || ! -x "$BIN" ]]; then
  log "installing Godot ${TAG} (not found in cache)"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT

  download "$SUMS_FILE" "$work" || log "could not download $SUMS_FILE"
  download "$ENGINE_ZIP" "$work" || die "could not download $ENGINE_ZIP"
  verify "$ENGINE_ZIP" "$work"
  unzip -q -o "$work/$ENGINE_ZIP" -d "$work/engine"
  engine_bin="$(find "$work/engine" -maxdepth 1 -type f -name 'Godot_v*' | head -n1)"
  [[ -n "$engine_bin" ]] || die "Godot binary not found inside $ENGINE_ZIP"
  install -m 0755 "$engine_bin" "$BIN"
  rm -f "$work/$ENGINE_ZIP"

  download "$TEMPLATES_TPZ" "$work" || die "could not download $TEMPLATES_TPZ"
  verify "$TEMPLATES_TPZ" "$work"
  # Only the Android templates are needed; skipping the rest saves a lot of disk space.
  unzip -q -o "$work/$TEMPLATES_TPZ" 'templates/android_*' 'templates/version.txt' -d "$work/tpl"
  rm -f "$work/$TEMPLATES_TPZ"
  mkdir -p "$CACHE_DIR/templates"
  cp -f "$work"/tpl/templates/* "$CACHE_DIR/templates/"

  touch "$STAMP"
  rm -rf "$work"
  trap - EXIT
else
  log "using cached Godot ${TAG}"
fi

[[ -f "$CACHE_DIR/templates/android_release.apk" ]] || die "android_release.apk template missing"
[[ -f "$CACHE_DIR/templates/android_debug.apk" ]] || die "android_debug.apk template missing"
cp -f "$CACHE_DIR"/templates/* "$TEMPLATE_DIR/"

if [[ -f "$TEMPLATE_DIR/version.txt" ]]; then
  found="$(tr -d '[:space:]' < "$TEMPLATE_DIR/version.txt")"
  expected_version="${GODOT_VERSION}.${GODOT_RELEASE}"
  [[ "$found" == "$expected_version" ]] || log "WARNING: template version '$found' differs from '$expected_version'"
fi

"$BIN" --version || true

# ---- Editor settings (Android SDK / JDK / signing key paths) ----------------------
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$CONFIG_DIR"

# Let Godot create its own settings file first, using a throwaway project.
bootstrap="$(mktemp -d)"
printf 'config_version=5\n\n[application]\nconfig/name="settings-bootstrap"\n' > "$bootstrap/project.godot"
"$BIN" --headless --editor --path "$bootstrap" --quit > /dev/null 2>&1 || true
rm -rf "$bootstrap"

mapfile -t settings_files < <(find "$CONFIG_DIR" -maxdepth 1 -type f -name 'editor_settings-*.tres')
if [[ ${#settings_files[@]} -eq 0 ]]; then
  major_minor="${GODOT_VERSION%.*}"
  for name in "editor_settings-4.tres" "editor_settings-${major_minor}.tres"; do
    printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$CONFIG_DIR/$name"
    settings_files+=("$CONFIG_DIR/$name")
  done
  log "created editor settings files manually"
fi

set_setting() {
  local file="$1" key="$2" value="$3"
  sed -i "\|^${key} = |d" "$file"
  printf '%s = %s\n' "$key" "$value" >> "$file"
}

for file in "${settings_files[@]}"; do
  printf '\n' >> "$file"
  set_setting "$file" "export/android/java_sdk_path" "\"${JAVA_HOME}\""
  set_setting "$file" "export/android/android_sdk_path" "\"${ANDROID_SDK_ROOT}\""
  set_setting "$file" "export/android/shutdown_adb_on_exit" "true"
  if [[ -n "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]]; then
    set_setting "$file" "export/android/debug_keystore" "\"${GODOT_ANDROID_KEYSTORE_DEBUG_PATH}\""
    set_setting "$file" "export/android/debug_keystore_user" "\"${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}\""
    set_setting "$file" "export/android/debug_keystore_pass" "\"${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}\""
  fi
  log "configured $(basename "$file")"
done

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "GODOT_BIN=$BIN" >> "$GITHUB_ENV"
fi
log "done. GODOT_BIN=$BIN"