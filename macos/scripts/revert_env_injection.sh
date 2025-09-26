#!/usr/bin/env bash
# revert_env_injection.sh – Resets plist, xcconfig, and project values back to their committed state after a build.

set -euo pipefail

# Skip if running from fastlane (fastlane handles cleanup itself)
if [[ "${FASTLANE_BUILD:-}" == "true" ]]; then
  echo "[revert_env] Skipping revert - running from fastlane"
  exit 0
fi

#--------------------------------------
# Paths and Placeholder
#--------------------------------------
INFO_PLIST="$SRCROOT/Runner/Info.plist"
PROJECT_FILE="$SRCROOT/Runner.xcodeproj/project.pbxproj"
PLACEHOLDER="TO_BE_REPLACED_BY_SCRIPT"
BUNDLE_ID_PLACEHOLDER="BUNDLE_ID_PLACEHOLDER"
TEAM_ID_PLACEHOLDER="TEAM_ID_PLACEHOLDER"

#--------------------------------------
# Helper to call PlistBuddy
#--------------------------------------
plist_delete() {
  /usr/libexec/PlistBuddy -c "Delete :$1" "$2" 2>/dev/null || true
}

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
revert_project_injections() {
  local ENV_FILE="$SRCROOT/../.env"
  
  if [[ -f "$PROJECT_FILE" && -f "$ENV_FILE" ]]; then
    # Extract the bundle ID from .env to replace it back with placeholder
    BUNDLE_ID=$(grep "^BUNDLE_ID" "$ENV_FILE" | cut -d'=' -f2 | xargs | tr -d "'\"")
    if [[ -n "$BUNDLE_ID" ]]; then
      sed -i '' "s/$BUNDLE_ID/$BUNDLE_ID_PLACEHOLDER/g" "$PROJECT_FILE"
      echo "[revert_env] Reverted bundle ID in project.pbxproj"
    fi
    
    # Extract the team ID from .env to replace it back with placeholder
    TEAM_ID=$(grep "^TEAM_ID" "$ENV_FILE" | cut -d'=' -f2 | xargs | tr -d "'\"")
    if [[ -n "$TEAM_ID" ]]; then
      sed -i '' "s/$TEAM_ID/$TEAM_ID_PLACEHOLDER/g" "$PROJECT_FILE"
      echo "[revert_env] Reverted team ID in project.pbxproj"
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
revert_project_injections

#--------------------------------------
# Revert Info.plist
#--------------------------------------
if [[ -f "$INFO_PLIST" ]]; then
  echo "[revert_env] Reverting macOS Info.plist"
  # These keys are added by the inject script, so we remove them to match the committed file.
  plist_delete "GIDClientID" "$INFO_PLIST"
  plist_delete "GIDServerClientID" "$INFO_PLIST"

  # This key has its value replaced, so we set it back to the placeholder.
  plist_set "CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLACEHOLDER" "$INFO_PLIST"
fi

echo "[revert_env] Successfully reverted macOS plist, xcconfig, and project files." 