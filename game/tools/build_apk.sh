#!/usr/bin/env bash
# One-command debug APK build for the owner's phone.
#   game/tools/build_apk.sh                 data → placeholders → import → tests → export → verify
#   game/tools/build_apk.sh --skip-tests
#   game/tools/build_apk.sh --force-art     regenerate placeholder art
#   game/tools/build_apk.sh --armv7         also build a separate APK for old 32-bit phones (armeabi-v7a)
#
# Why armv7 is a separate APK: the Godot 4.7.2 engine library for armeabi-v7a adds ~32 MB to the debug APK
# (~26 MB in release), so a combined arm64 + v7 APK would grow from ~29 MB to ~61 MB. Google Play builds
# (AAB) split per ABI anyway; for side-loading on an old phone use the armv7 APK.
#
# Needs (installed outside the repo, see game/README.md):
#   GODOT        Godot 4.7.2 binary              (default: godot in PATH)
#   export templates 4.7.2 in ~/.local/share/godot/export_templates/4.7.2.stable/
#   ANDROID_HOME Android SDK: platform-tools, build-tools 36.1.0, platforms;android-36 (default /opt/android-sdk)
#   JAVA_HOME    JDK 17                           (default /usr/lib/jvm/java-17-openjdk-amd64)
#   DEBUG_KEYSTORE  debug keystore, generated on first run if missing (default ~/.android/debug.keystore)
# Nothing secret is stored in the repository: the debug keystore lives in the home directory.
set -euo pipefail

GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$GAME_DIR/.." && pwd)"
OUT_DIR="$REPO_DIR/builds"
APK="$OUT_DIR/owlight-slice01-debug.apk"
APK_V7="$OUT_DIR/owlight-slice01-debug-armv7.apk"

export GODOT="${GODOT:-godot}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
DEBUG_KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
BUILD_TOOLS="$ANDROID_HOME/build-tools/36.1.0"

skip_tests=0
force_art=""
armv7=0
for a in "$@"; do
  case "$a" in
    --skip-tests) skip_tests=1 ;;
    --force-art) force_art="--force" ;;
    --armv7) armv7=1 ;;
    *) echo "unknown option $a"; exit 2 ;;
  esac
done

need() { [ -e "$1" ] || { echo "missing: $1 ($2)"; exit 1; }; }
command -v "$GODOT" >/dev/null || { echo "Godot not found: set GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64"; exit 1; }
need "$ANDROID_HOME/platform-tools" "Android SDK platform-tools"
need "$BUILD_TOOLS/apksigner" "build-tools 36.1.0"
need "$JAVA_HOME/bin/keytool" "JDK 17"
need "$HOME/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk" "Godot 4.7.2 export templates"
echo "Godot $("$GODOT" --version)"

echo "== data and placeholder art"
python3 "$GAME_DIR/tools/data_build.py"
python3 "$GAME_DIR/tools/gen_placeholders.py" $force_art

echo "== import"
"$GODOT" --headless --path "$GAME_DIR" --import >/dev/null 2>&1

if [ "$skip_tests" -eq 0 ]; then
  "$GAME_DIR/tools/run_tests.sh"
fi

if [ ! -f "$DEBUG_KEYSTORE" ]; then
  echo "== generating local debug keystore at $DEBUG_KEYSTORE (not part of the repo)"
  mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$DEBUG_KEYSTORE" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
# Standard Android debug-key credentials (public, debug only). Release signing is never done here.
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

echo "== export debug APK"
mkdir -p "$OUT_DIR"
rm -f "$APK" "$APK.idsig"
"$GODOT" --headless --path "$GAME_DIR" --export-debug "Android" "$APK" >"$OUT_DIR/export.log" 2>&1 || {
  tail -40 "$OUT_DIR/export.log"; echo "EXPORT FAILED (log: $OUT_DIR/export.log)"; exit 1; }
[ -f "$APK" ] || { tail -40 "$OUT_DIR/export.log"; echo "EXPORT FAILED: no APK"; exit 1; }

verify() {
  "$BUILD_TOOLS/apksigner" verify --verbose "$1" 2>/dev/null | grep -E "^Verifies|v2 scheme|v3 scheme"
  "$BUILD_TOOLS/aapt2" dump badging "$1" 2>/dev/null | grep -E "^package:|targetSdkVersion|sdkVersion|application-label:|native-code"
  echo "APK: $1 ($(du -h "$1" | cut -f1))"
}
echo "== verify"
verify "$APK"

if [ "$armv7" -eq 1 ]; then
  echo "== export debug APK for armeabi-v7a (old 32-bit phones)"
  rm -f "$APK_V7" "$APK_V7.idsig"
  "$GODOT" --headless --path "$GAME_DIR" --export-debug "Android armv7" "$APK_V7" >"$OUT_DIR/export-armv7.log" 2>&1 || {
    tail -40 "$OUT_DIR/export-armv7.log"; echo "EXPORT FAILED (log: $OUT_DIR/export-armv7.log)"; exit 1; }
  verify "$APK_V7"
fi
echo "Install: adb install -r \"$APK\"  (or copy the file to the phone and open it)"
