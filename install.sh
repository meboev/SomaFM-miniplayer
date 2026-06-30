#!/bin/bash
set -e

DMG_NAME="SomaFM-miniplayer-2.0.3.dmg"
APP_NAME="SomaFM miniplayer.app"
VOLUME_NAME="SomaFM miniplayer"
INSTALL_DIR="/Applications"

if [ ! -f "$DMG_NAME" ]; then
  echo "Error: $DMG_NAME not found. Run ./create-dmg.sh first."
  exit 1
fi

echo "Mounting $DMG_NAME..."
hdiutil attach "$DMG_NAME" -nobrowse -quiet
MOUNT_POINT="/Volumes/$VOLUME_NAME"

if [ ! -d "$MOUNT_POINT/$APP_NAME" ]; then
  echo "Error: $APP_NAME not found in mounted DMG."
  hdiutil detach "$MOUNT_POINT" -quiet
  exit 1
fi

echo "Installing $APP_NAME to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$MOUNT_POINT/$APP_NAME" "$INSTALL_DIR/"

echo "Unmounting..."
hdiutil detach "$MOUNT_POINT" -quiet

echo "Done. $APP_NAME installed to $INSTALL_DIR."
