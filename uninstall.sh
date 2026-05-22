#!/bin/bash

APP_NAME="SomaFM miniplayer.app"
INSTALL_DIR="/Applications"
BUNDLE_ID="com.milenboev.somafm"

echo "Quitting $APP_NAME if running..."
osascript -e 'tell application "SomaFM miniplayer" to quit' 2>/dev/null || true
pkill -f "SomaFM miniplayer" 2>/dev/null || true
sleep 1

if [ ! -d "$INSTALL_DIR/$APP_NAME" ]; then
  echo "$APP_NAME is not installed. Nothing to remove."
  exit 0
fi

echo "Removing $INSTALL_DIR/$APP_NAME..."
rm -rf "$INSTALL_DIR/$APP_NAME"

echo "Removing preferences..."
defaults delete ${BUNDLE_ID} 2>/dev/null || true
rm -f ~/Library/Preferences/${BUNDLE_ID}.plist

echo "Removing cached data..."
rm -rf "$HOME/Library/Application Support/SomaFM miniplayer" 2>/dev/null || true
rm -rf ~/Library/Caches/${BUNDLE_ID} 2>/dev/null || true
rm -rf ~/Library/Containers/${BUNDLE_ID} 2>/dev/null || true

echo "Done. $APP_NAME has been uninstalled."
