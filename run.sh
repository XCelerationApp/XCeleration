#!/bin/bash

# Script to run the main production version of XCeleration

echo "Launching XCeleration Production version..."

# Check if a device ID was provided
if [ -z "$1" ]; then
  echo "Looking for iPhone device..."
  # First, just list available devices
  flutter devices
  
  # Find iPhone device ID from the list
  DEVICE_ID=$(flutter devices | grep -i "iphone" | head -1 | awk -F'•' '{print $2}' | xargs)
  
  if [ -n "$DEVICE_ID" ]; then
    echo "Found iPhone device: $DEVICE_ID"
    # Run the app with production entry point
    echo "Building and installing production version..."
    flutter run -d "$DEVICE_ID" --debug "$@"
  else
    echo "No iPhone found. Please connect your iPhone or specify a device ID."
    exit 1
  fi
else
  # Use the provided device ID
  flutter run -d "$1" --debug "${@:2}"
fi
