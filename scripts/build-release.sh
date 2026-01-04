#!/bin/bash
set -e

# =============================================================================
# GitHub Pet - Build Script
# =============================================================================
#
# Builds the app and creates a distributable .app bundle
#
# Usage:
#   ./scripts/build-release.sh
#
# For release builds with custom Client ID:
#   GITHUB_CLIENT_ID=your_id ./scripts/build-release.sh
#
# =============================================================================

APP_NAME="PRNeko"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
RESOURCES_DIR="$PROJECT_DIR/Sources/PRNeko/Resources"

echo "Building $APP_NAME v$VERSION..."

cd "$PROJECT_DIR"

# Build release
swift build -c release

# Create .app bundle
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Update version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"

# Copy assets
cp -r "$PROJECT_DIR/Sources/PRNeko/Assets/"* "$APP_BUNDLE/Contents/Resources/"

echo ""
echo "Build complete!"
echo "  App: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
