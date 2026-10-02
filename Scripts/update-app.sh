#!/bin/bash
#
# update-app.sh
# The one-command way to get the latest merged `main` running in your own
# /Applications folder: pulls main, runs release.sh (archive, sign,
# notarize, staple, package — see that script for prerequisites), then
# quits the running app, swaps in the freshly built one, and relaunches it.
#
# Refuses to touch anything if there are uncommitted changes, or if main
# can't be fast-forwarded cleanly (that means local main has commits
# origin doesn't, which this script isn't the place to resolve).
#
# Usage: Scripts/update-app.sh

set -euo pipefail

APP_NAME="Nibora"
BUNDLE_ID="com.chataeubacon.app.Nibora"
INSTALL_PATH="/Applications/$APP_NAME.app"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Checking for uncommitted changes to tracked files =="
# --untracked-files=no deliberately ignores untracked files/directories —
# git checkout and merge --ff-only never touch those, so they pose no risk
# here even though `git status` would otherwise flag them as "dirty."
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "error: you have uncommitted changes to tracked files. Commit, stash, or discard them first — this script won't switch branches or pull over work in progress." >&2
  git status --short --untracked-files=no >&2
  exit 1
fi

echo "== Fetching and fast-forwarding main =="
git fetch origin
git checkout main
if ! git merge --ff-only origin/main; then
  echo "error: local main has commits origin/main doesn't (or has diverged). Resolve that first — this script only ever fast-forwards." >&2
  exit 1
fi

echo "== Building, signing, and notarizing (this takes a few minutes) =="
"$ROOT_DIR/Scripts/release.sh"

VERSION=$(xcodebuild -project "$ROOT_DIR/Nibora.xcodeproj" -showBuildSettings -scheme "$APP_NAME" 2>/dev/null | awk -F'= ' '/MARKETING_VERSION/{print $2; exit}')
DMG_PATH="$ROOT_DIR/build/release/$APP_NAME-$VERSION.dmg"
if [ ! -f "$DMG_PATH" ]; then
  echo "error: release.sh didn't produce the expected $DMG_PATH" >&2
  exit 1
fi

echo "== Mounting the built .dmg =="
MOUNT_POINT=$(mktemp -d "$ROOT_DIR/build/mount.XXXXXX")
hdiutil attach "$DMG_PATH" -nobrowse -mountpoint "$MOUNT_POINT" >/dev/null
trap 'hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true; rmdir "$MOUNT_POINT" 2>/dev/null || true' EXIT

MOUNTED_APP="$MOUNT_POINT/$APP_NAME.app"
if [ ! -d "$MOUNTED_APP" ]; then
  echo "error: no $APP_NAME.app found inside the mounted .dmg" >&2
  exit 1
fi

echo "== Verifying the mounted app before touching /Applications =="
codesign --verify --deep --strict "$MOUNTED_APP"
spctl -a -vvv --type execute "$MOUNTED_APP"

echo "== Quitting the running app, if any =="
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
sleep 1

echo "== Installing to $INSTALL_PATH =="
# Copy the new one in under a temp name first and verify it landed intact,
# so a failure partway through never leaves /Applications with no app at
# all — only once that's confirmed does the old one get replaced.
STAGED_PATH="$INSTALL_PATH.updating"
rm -rf "$STAGED_PATH"
ditto "$MOUNTED_APP" "$STAGED_PATH"
codesign --verify --deep --strict "$STAGED_PATH"

rm -rf "$INSTALL_PATH"
mv "$STAGED_PATH" "$INSTALL_PATH"

echo "== Relaunching =="
open "$INSTALL_PATH"

echo
echo "Done: $APP_NAME $VERSION installed to $INSTALL_PATH and relaunched."
