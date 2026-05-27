#!/bin/bash
set -e

APP_PATH="./build/Release/SomaFM miniplayer.app"
DMG_NAME="SomaFM-miniplayer-2.0.2.dmg"
DMG_DIR="./dmg_contents"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: $APP_PATH not found. Run ./build.sh first."
  exit 1
fi

echo "Preparing DMG contents..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

echo "Creating $DMG_NAME..."
rm -f "$DMG_NAME"
hdiutil create -volname "SomaFM miniplayer" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_NAME"

echo "Cleaning up..."
rm -rf "$DMG_DIR"
rm -rf ./build

echo "Done: $DMG_NAME"
