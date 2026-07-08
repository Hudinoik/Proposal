#!/bin/bash
# Installs and opens the TCO Agreement Generator on your Mac.
# Ships inside the Mac ZIPs as "Fix and Open (Mac).command": it clears
# Apple's download-quarantine flag (which makes macOS refuse to load the
# app's own Electron Framework — dyld "different Team IDs" crash on
# ad-hoc-signed downloads), installs into Applications, and opens the app.
cd "$(dirname "$0")"
APP="TCO Agreement Generator.app"
if [ ! -d "$APP" ]; then
  echo "Could not find '$APP' next to this file."
  echo "Please unzip the whole download first, then open this file again."
  read -r -p "Press Enter to close this window."
  exit 1
fi
echo "Preparing the app (removing Apple's download flag)..."
xattr -cr "$APP" 2>/dev/null || true
echo "Installing into Applications..."
rm -rf "/Applications/$APP"
cp -Rp "$APP" /Applications/
xattr -cr "/Applications/$APP" 2>/dev/null || true
echo "Opening the app..."
open "/Applications/$APP"
echo
echo "Done — TCO Agreement Generator is installed."
echo "From now on, open it from Applications like any other app."
read -r -p "You can close this window (press Enter)."
