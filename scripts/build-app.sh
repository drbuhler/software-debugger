#!/usr/bin/env bash
# Builds Software-Debugger-4.2-hmst.app for the Mac you are sitting at.
# The project is Hamster Infestation. The file you install has the plain name.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This builds a Mac app. Run it on your Mac, in Terminal."
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "The Swift compiler is not installed."
  echo "Install Xcode from the App Store, open it once and click Agree, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "Compiling. The first build can take a minute or two."
# macOS 12 is the oldest system this app claims to support.
# Newer calls are wrapped so they are not used on macOS 12.
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"
swift build -c release --product HamsterInfestation

BIN_DIR="$(swift build -c release --product HamsterInfestation --show-bin-path)"
BINARY="${BIN_DIR}/HamsterInfestation"
if [[ ! -x "$BINARY" ]]; then
  echo "The build finished, but the program was not where it should be:"
  echo "  $BINARY"
  exit 1
fi

APP_NAME="Software-Debugger-4.2-hmst"
APP="${ROOT}/dist/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/${APP_NAME}"
chmod +x "$APP/Contents/MacOS/${APP_NAME}"
cp "${ROOT}/packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [[ -d "${ROOT}/Sources/HamsterInfestation/Resources" ]]; then
  cp "${ROOT}/Sources/HamsterInfestation/Resources/"* "$APP/Contents/Resources/"
fi
cp "${ROOT}/scripts/minus-hamster" "$APP/Contents/Resources/terminal-command.sh"
chmod +x "$APP/Contents/Resources/terminal-command.sh"

ICONSET="${ROOT}/packaging/AppIcon.iconset"
if command -v iconutil >/dev/null 2>&1 && [[ -d "$ICONSET" ]]; then
  if ! iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"; then
    echo "The icon could not be built. The app will still run."
  fi
fi

if command -v codesign >/dev/null 2>&1; then
  # Ad-hoc signature only. This is not a paid Apple signature.
  # The first launch still needs a right-click and Open.
  codesign --force --sign - "$APP" || echo "The app was built, but it could not be signed."
else
  echo "codesign was not found. The app was built."
fi

ZIP="${ROOT}/dist/${APP_NAME}.zip"
rm -f "$ZIP"
if command -v ditto >/dev/null 2>&1; then
  ditto -c -k --keepParent "$APP" "$ZIP"
else
  echo "ditto was not found, so no zip file was made. The app itself is ready."
fi

DMG="${ROOT}/dist/${APP_NAME}.dmg"
rm -f "$DMG"
if command -v hdiutil >/dev/null 2>&1; then
  hdiutil create -volname "Software Debugger" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null || echo "No disk image was made. The app itself is ready."
fi

echo
echo "Built:"
echo "  ${APP}"
if [[ -f "$ZIP" ]]; then
  echo "  ${ZIP}"
fi
if [[ -f "$DMG" ]]; then
  echo "  ${DMG}"
fi
echo
echo "In Finder this app is named Software Debugger. The hmst in the file name is the hint."
echo
echo "Install it with:"
echo "  cp -R \"${APP}\" /Applications/"
echo
echo "Then open Finder, go to Applications, right-click Software Debugger, and choose Open."
echo "The first time, click Open again in the dialog."
