#!/usr/bin/env bash
# revert_env.sh – Resets plist, xcconfig, and project values back to their committed state after a build.

set -euo pipefail

#--------------------------------------
# Paths and Placeholder
#--------------------------------------
INFO_PLIST="$SRCROOT/Runner/Info.plist"
PROJECT_FILE="$SRCROOT/Runner.xcodeproj/project.pbxproj"
PLACEHOLDER="TO_BE_REPLACED_BY_SCRIPT"
BUNDLE_ID_PLACEHOLDER="BUNDLE_ID_PLACEHOLDER"

#--------------------------------------
# Helper to call PlistBuddy
#--------------------------------------
plist_set() {
  /usr/libexec/PlistBuddy -c "Set :$1 $2" "$3"
}

#--------------------------------------
# Helper to revert xcconfig files
#--------------------------------------
revert_bundle_id_in_xcconfig() {
  local XCCONFIG_FILE="$1"
  local ENV_FILE="$SRCROOT/../.env"
  
  if [[ -f "$XCCONFIG_FILE" && -f "$ENV_FILE" ]]; then
    # Extract the bundle ID from .env to replace it back with placeholder
    BUNDLE_ID=$(grep "^BUNDLE_ID" "$ENV_FILE" | cut -d'=' -f2 | xargs | tr -d "'\"")
    if [[ -n "$BUNDLE_ID" ]]; then
      sed -i '' "s/$BUNDLE_ID/$BUNDLE_ID_PLACEHOLDER/g" "$XCCONFIG_FILE"
      echo "[revert_env] Reverted bundle ID in $XCCONFIG_FILE"
    fi
  fi
}

#--------------------------------------
# Helper to revert project.pbxproj
#--------------------------------------
revert_bundle_id_in_project() {
  local ENV_FILE="$SRCROOT/../.env"
  
  if [[ -f "$PROJECT_FILE" && -f "$ENV_FILE" ]]; then
    # Extract the bundle ID from .env to replace it back with placeholder
    BUNDLE_ID=$(grep "^BUNDLE_ID" "$ENV_FILE" | cut -d'=' -f2 | xargs | tr -d "'\"")
    if [[ -n "$BUNDLE_ID" ]]; then
      sed -i '' "s/$BUNDLE_ID/$BUNDLE_ID_PLACEHOLDER/g" "$PROJECT_FILE"
      echo "[revert_env] Reverted bundle ID in project.pbxproj"
    fi
  fi
}

#--------------------------------------
# Revert xcconfig files
#--------------------------------------
revert_bundle_id_in_xcconfig "$SRCROOT/Runner/Configs/AppInfo.xcconfig"

#--------------------------------------
# Revert project.pbxproj
#--------------------------------------
revert_bundle_id_in_project

#--------------------------------------
# Revert Info.plist
#--------------------------------------
if [[ -f "$INFO_PLIST" ]]; then
  echo "[revert_env] Reverting macOS Info.plist"
  # This key has its value replaced, so we set it back to the placeholder.
  plist_set "CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLACEHOLDER" "$INFO_PLIST"
fi

echo "[revert_env] Successfully reverted macOS plist, xcconfig, and project files." 