#!/usr/bin/env bash
# Build and run iOS app on simulator or device
# Usage: ./scripts/build-and-run.sh [simulator|device] [device-name]

set -e

PROJECT_PATH="ios-app/GPTReminders.xcodeproj"
SCHEME="GPTReminders"
DESTINATION="${1:-simulator}"
DEVICE_NAME="${2:-iPhone 15 Pro}"
DEBUG_FLAG="${3:-}"

DEBUG_MODE="false"
if [ "$DEBUG_FLAG" = "--debug" ]; then
  DEBUG_MODE="true"
fi

echo "🔨 Building and running iOS app..."
echo "   Destination: $DESTINATION"
echo "   Device: $DEVICE_NAME"
if [ "$DEBUG_MODE" = "true" ]; then
  echo "   Debug Mode: ON"
else
  echo "   Debug Mode: OFF"
fi
echo ""

if [ "$DESTINATION" = "simulator" ]; then
  # List available simulators
  echo "Available simulators:"
  xcrun simctl list devices available | grep -E "iPhone|iPad" | head -5
  echo ""

  # Get simulator UDID
  SIM_UDID=$(xcrun simctl list devices available | grep "$DEVICE_NAME" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)

  if [ -z "$SIM_UDID" ]; then
    echo "❌ Error: Simulator '$DEVICE_NAME' not found"
    echo "   Available simulators:"
    xcrun simctl list devices available | grep -E "iPhone|iPad"
    exit 1
  fi

  echo "📱 Using simulator: $DEVICE_NAME ($SIM_UDID)"
  echo ""

  # Build the app
  echo "🔨 Building app..."

  # Configure build settings based on debug mode
  BUILD_SETTINGS=""
  if [ "$DEBUG_MODE" = "true" ]; then
    BUILD_SETTINGS="SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG_TOOLS"
  fi

  if ! xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$SIM_UDID" \
    -derivedDataPath build \
    $BUILD_SETTINGS \
    clean build; then
    echo "❌ Build failed"
    exit 1
  fi

  # Find the built app
  APP_PATH="build/Build/Products/Debug-iphonesimulator/GPTReminders.app"
  if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Could not find built app at $APP_PATH"
    exit 1
  fi

  # Boot simulator if not running
  echo "🚀 Booting simulator..."
  xcrun simctl boot "$SIM_UDID" 2> /dev/null || true

  # Install app
  echo "📦 Installing app..."
  xcrun simctl install "$SIM_UDID" "$APP_PATH"

  # Launch app
  echo "▶️  Launching app..."
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist")
  xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"

  echo ""
  echo "✅ App launched on simulator"
  echo "   View logs: xcrun simctl spawn $SIM_UDID log stream --predicate 'processImagePath contains \"GPTReminders\"'"
else
  # Build for device (requires manual selection in Xcode for signing)
  echo "⚠️  Device builds require Xcode GUI for code signing"
  echo "   Opening Xcode..."
  open "$PROJECT_PATH"
  echo ""
  echo "   In Xcode:"
  echo "   1. Select your device from device menu"
  echo "   2. Press ⌘R to build and run"
fi
