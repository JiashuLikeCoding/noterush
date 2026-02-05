#!/usr/bin/env bash
set -euo pipefail

# One-click deploy + launch to Jiashu’s iPhone.
# Usage:
#   ./scripts/run_on_jiashu_iphone.sh
# Optional overrides:
#   DEVICE_ID="<udid>" SCHEME="NoteRush" CONFIGURATION="Debug" ./scripts/run_on_jiashu_iphone.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/NoteRush.xcodeproj}"
SCHEME="${SCHEME:-NoteRush}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DEVICE_ID="${DEVICE_ID:-00008140-001615061A33001C}"   # Jiashu’s iPhone
# Important: keep DerivedData OUTSIDE iCloud-synced folders (e.g. ~/Documents).
# Otherwise Xcode may add FileProvider xattrs (com.apple.fileprovider.*) and codesign fails with:
#   "resource fork, Finder information, or similar detritus not allowed"
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/NoteRush-CLI}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: Xcode project not found at: $PROJECT_PATH" >&2
  exit 1
fi

echo "==> Clearing extended attributes (fixes codesign: resource fork detritus)"
# This avoids: "resource fork, Finder information, or similar detritus not allowed"
# Common after copying assets via AirDrop/Downloads or from external drives.
xattr -cr "$ROOT_DIR/NoteRush" 2>/dev/null || true

# Ensure DerivedData location exists and is clean of xattrs.
mkdir -p "$DERIVED_DATA"
xattr -cr "$DERIVED_DATA" 2>/dev/null || true

echo "==> Building ($SCHEME, $CONFIGURATION) for device: $DEVICE_ID"

action_build=(
  xcodebuild
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "platform=iOS,id=$DEVICE_ID"
  -derivedDataPath "$DERIVED_DATA"
  -sdk iphoneos
  build
)

"${action_build[@]}"

echo "==> Locating built .app"
APP_PATH="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -type d -name "*.app" | head -n 1)"
if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: Could not find built .app under: $DERIVED_DATA/Build/Products" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  echo "ERROR: Missing Info.plist at: $INFO_PLIST" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print:CFBundleIdentifier' "$INFO_PLIST" 2>/dev/null || true)"
if [[ -z "${BUNDLE_ID:-}" ]]; then
  echo "ERROR: Could not read CFBundleIdentifier from: $INFO_PLIST" >&2
  exit 1
fi

echo "==> Installing: $APP_PATH"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "==> Launching: $BUNDLE_ID"
xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID" >/dev/null

echo "✅ Done. Launched $BUNDLE_ID on device $DEVICE_ID"
