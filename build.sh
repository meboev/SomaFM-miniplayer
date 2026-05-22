#!/bin/bash
set -e

SCHEME="SomaFM"
CONFIGURATION="Release"
BUILD_DIR="$(pwd)/build"

echo "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Building $SCHEME ($CONFIGURATION, arm64)..."
xcodebuild -project SomaFM.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  SYMROOT="$BUILD_DIR" \
  build \
  | xcbeautify

echo "Build complete: $BUILD_DIR/$CONFIGURATION/SomaFM miniplayer.app"
