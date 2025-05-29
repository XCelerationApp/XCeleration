#!/bin/bash

# Script to directly modify the Xcode project to create a separate dev app

echo "Setting up development version of XCeleration..."

# Note: We're not modifying Info.plist anymore, just running the app
# Make sure Info.plist has the display name you want manually set before running

echo "Starting development version - using current Info.plist settings..."

# For dev builds, manually ensure Info.plist has:
# <key>CFBundleDisplayName</key>
# <string>XCeleration Dev</string>
# <key>CFBundleName</key>
# <string>XCeleration Dev</string>

# 4. Use the development app icon
echo "Updating app icon to development version..."
# Check if the development icon exists
if [ -f "assets/icon/XCeleration_icon_dev.png" ]; then
  echo "Found development icon, generating iOS app icons..."
  
  # Create a temporary directory for icon generation
  ICON_TEMP_DIR=$(mktemp -d)
  
  # Copy the dev icon to the temp directory
  cp "assets/icon/XCeleration_icon_dev.png" "$ICON_TEMP_DIR/dev_icon.png"
  
  # Use sips (built-in macOS image processing tool) to resize the icon for different iOS sizes
  # The most important one is the 1024x1024 icon
  sips -z 1024 1024 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" &>/dev/null
  
  # Generate other required iOS icon sizes
  sips -z 20 20 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png" &>/dev/null
  sips -z 40 40 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png" &>/dev/null
  sips -z 60 60 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png" &>/dev/null
  sips -z 29 29 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png" &>/dev/null
  sips -z 58 58 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png" &>/dev/null
  sips -z 87 87 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png" &>/dev/null
  sips -z 40 40 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png" &>/dev/null
  sips -z 80 80 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png" &>/dev/null
  sips -z 120 120 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png" &>/dev/null
  sips -z 76 76 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png" &>/dev/null
  sips -z 152 152 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png" &>/dev/null
  sips -z 167 167 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png" &>/dev/null
  sips -z 120 120 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png" &>/dev/null
  sips -z 180 180 "$ICON_TEMP_DIR/dev_icon.png" --out "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png" &>/dev/null
  
  # Clean up the temp directory
  rm -rf "$ICON_TEMP_DIR"
  
  echo "App icon updated successfully."
else
  echo "Warning: Development icon not found at assets/icon/XCeleration_icon_dev.png"
  echo "Using the default app icon instead."
fi

# Check if a device ID was provided
if [ -z "$1" ]; then
  echo "Looking for iPhone device..."
  # First, just list available devices
  flutter devices
  
  # Find iPhone device ID from the list
  DEVICE_ID=$(flutter devices | grep -i "iphone" | head -1 | awk -F'•' '{print $2}' | xargs)
  
  if [ -n "$DEVICE_ID" ]; then
    echo "Found iPhone device: $DEVICE_ID"
    # Run the app with development entry point and flavor
    echo "Building and installing development version..."
    flutter clean
    flutter run -d "$DEVICE_ID" -t lib/main_dev.dart --debug
    
    # Restore original files
    echo "Restoring original project files..."
    cp ~/ios_backup/project.pbxproj.bak ios/Runner.xcodeproj/project.pbxproj 2>/dev/null || true
    
    # Restore original app icons
    echo "Restoring original app icons..."
    cp -f ~/ios_backup/AppIcon.appiconset/* ios/Runner/Assets.xcassets/AppIcon.appiconset/ 2>/dev/null || true
  else
    echo "No iPhone found. Please connect your iPhone or specify a device ID."
    exit 1
  fi
else
  # Use the provided device ID
  flutter clean
  flutter run -d "$1" -t lib/main_dev.dart --debug
  
  # Restore original files
  echo "Restoring original project files..."
  cp ~/ios_backup/project.pbxproj.bak ios/Runner.xcodeproj/project.pbxproj 2>/dev/null || true
  
  # Restore original app icons
  echo "Restoring original app icons..."
  cp -f ~/ios_backup/AppIcon.appiconset/* ios/Runner/Assets.xcassets/AppIcon.appiconset/ 2>/dev/null || true
fi
