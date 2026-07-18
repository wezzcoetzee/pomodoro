#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.1.0}"
APP_NAME="Pomodoro"

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"
DERIVED="$ROOT/build"

# xcode-select points at CommandLineTools on this machine; override per-command
# so no sudo is needed.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "▸ Regenerating project…"
xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT"

echo "▸ Building release…"
xcodebuild \
  -project "$ROOT/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION" \
  build >/dev/null

BUILT="$DERIVED/Build/Products/Release/$APP_NAME.app"

# Sign and package from a temp dir so the source tree stays clean.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/$APP_NAME.app"
ditto "$BUILT" "$APP"

echo "▸ Ad-hoc signing…"
codesign --force --options runtime --sign - "$APP"
codesign --verify --strict "$APP"

mkdir -p "$DIST"
rm -rf "$DIST/$APP_NAME.app"
ditto "$APP" "$DIST/$APP_NAME.app"

echo "▸ Zipping…"
ZIP="$DIST/$APP_NAME-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "▸ Building DMG…"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
STAGE="$WORK/dmg/$APP_NAME"
rm -f "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -ov "$DMG" >/dev/null

echo "✓ Done: $ZIP"
echo "✓ Done: $DMG"
