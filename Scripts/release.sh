#!/bin/bash
#
# release.sh
# Builds Nibora, signs it for direct (non-App-Store) distribution, submits
# it to Apple for notarization, staples the ticket, and packages the result
# as a .dmg ready to upload as a GitHub release asset.
#
# Prerequisites (one-time, done outside this script — see README.md):
#   1. A "Developer ID Application" certificate for team 5TE942STS9,
#      installed in this Mac's keychain.
#   2. Notarization credentials stored under the keychain profile name
#      below, via:
#        xcrun notarytool store-credentials "nibora-notarize" \
#          --apple-id "you@example.com" --team-id 5TE942STS9
#      (it will prompt for an app-specific password from appleid.apple.com
#      — not your regular Apple ID password)
#
# Usage: Scripts/release.sh

set -euo pipefail

KEYCHAIN_PROFILE="nibora-notarize"
SCHEME="Nibora"
APP_NAME="Nibora"
BUNDLE_ID="com.chataeubacon.app.Nibora"
DEVELOPER_ID_IDENTITY="Developer ID Application: Michael Williams (5TE942STS9)"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"

# No physical Info.plist to read (GENERATE_INFOPLIST_FILE = YES), so pull
# the version straight from the project's build settings instead.
VERSION=$(xcodebuild -project "$ROOT_DIR/Nibora.xcodeproj" -showBuildSettings -scheme "$SCHEME" 2>/dev/null | awk -F'= ' '/MARKETING_VERSION/{print $2; exit}')
FINAL_DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "== Checking notarization credentials are stored =="
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
  echo "error: no notarytool credentials found under profile '$KEYCHAIN_PROFILE'." >&2
  echo "Run: xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" --apple-id \"you@example.com\" --team-id 5TE942STS9" >&2
  exit 1
fi

echo "== Checking a Developer ID Application certificate is installed =="
if ! security find-identity -v -p codesigning | grep -qF "$DEVELOPER_ID_IDENTITY"; then
  echo "error: '$DEVELOPER_ID_IDENTITY' not found in the keychain." >&2
  echo "Create one via Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "== Archiving ($VERSION) =="
xcodebuild archive \
  -project "$ROOT_DIR/Nibora.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  DEVELOPMENT_TEAM=5TE942STS9

echo "== Exporting (Developer ID signed) =="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$ROOT_DIR/Scripts/ExportOptions.plist"

echo "== Verifying the exported app's signature =="
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "== Zipping for notarization submission =="
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "== Submitting for notarization (this can take a few minutes) =="
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "== Stapling the notarization ticket to the app =="
xcrun stapler staple "$APP_PATH"

echo "== Verifying Gatekeeper acceptance =="
spctl -a -vvv --type execute "$APP_PATH"

echo "== Building the .dmg =="
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
ditto "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"

# The .app above already carries its own stapled ticket, but the .dmg is a
# separate container that was never itself submitted to Apple — stapling a
# ticket only works on the exact artifact that was notarized. hdiutil also
# doesn't sign what it creates, and an unsigned file fails Gatekeeper's
# assessment even with a valid ticket attached. So the .dmg needs its own
# signature and its own notarization pass, in that order.
echo "== Signing the .dmg =="
codesign --sign "$DEVELOPER_ID_IDENTITY" --timestamp "$DMG_PATH"

echo "== Submitting the .dmg for notarization =="
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "== Stapling the .dmg =="
xcrun stapler staple "$DMG_PATH"

echo "== Verifying Gatekeeper acceptance of the .dmg =="
spctl -a -vvv --type open --context context:primary-signature "$DMG_PATH"

mv "$DMG_PATH" "$FINAL_DMG"

echo
echo "Done: $FINAL_DMG"
echo "Verify with: spctl -a -vvv --type open --context context:primary-signature \"$FINAL_DMG\""
