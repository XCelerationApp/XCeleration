#!/usr/bin/env bash
# inject_env.sh – reads .env and writes required keys into macOS Info.plist, xcconfig files, and project configuration
# This script is intended to be called from an Xcode "Run Script" build phase.
# It makes the .env file the single source of truth for both Dart runtime and
# native-side values required at compile time.

set -euo pipefail

# Skip if running from fastlane (fastlane handles injection itself)
if [[ "${FASTLANE_BUILD:-}" == "true" ]]; then
  echo "[inject_env] Skipping injection - running from fastlane"
  exit 0
fi

#--------------------------------------
# Paths
#--------------------------------------
# $SRCROOT points at macos/ by default when invoked by Xcode for a macOS target.
ENV_FILE="$SRCROOT/../.env"
PLIST_FILE="$SRCROOT/Runner/Info.plist"
PROJECT_FILE="$SRCROOT/Runner.xcodeproj/project.pbxproj"

#--------------------------------------
# Early exit when .env is absent (e.g. Xcode indexing or teammate without secrets)
#--------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[inject_env] .env not found at $ENV_FILE – skipping plist injection."
  exit 0
fi

#--------------------------------------
# Parse required keys from .env (simple key=value, ignores comments)
#--------------------------------------
GID_CLIENT_ID=""
REVERSED_CLIENT_ID=""
GID_SERVER_CLIENT_ID=""
BUNDLE_ID=""
TEAM_ID=""

while IFS= read -r LINE; do
  # Ignore comments, empty lines, and lines without '='
  if [[ "$LINE" =~ ^# || -z "$LINE" || "$LINE" != *"="* ]]; then
    continue
  fi

  # Split on the first '='
  KEY="${LINE%%=*}"
  VALUE="${LINE#*=}"
  
  # Trim whitespace from KEY
  KEY=$(echo "$KEY" | xargs)

  # Trim whitespace, quotes, and any trailing characters like % from VALUE
  VALUE=$(echo "$VALUE" | xargs | tr -d "'\"%" | sed 's/[[:space:]]*$//')

  case "$KEY" in
    GOOGLE_IOS_OAUTH_CLIENT_ID) GID_CLIENT_ID="$VALUE" ;;
    GOOGLE_IOS_OAUTH_REVERSED_CLIENT_ID) REVERSED_CLIENT_ID="$VALUE" ;;
    GOOGLE_WEB_OAUTH_CLIENT_ID) GID_SERVER_CLIENT_ID="$VALUE" ;;
    BUNDLE_ID) BUNDLE_ID="$VALUE" ;;
    TEAM_ID) TEAM_ID="$VALUE" ;;
  esac
done < "$ENV_FILE"

# Validate presence
if [[ -z "$REVERSED_CLIENT_ID" || -z "$BUNDLE_ID" ]]; then
  echo "[inject_env] Required keys (REVERSED_CLIENT_ID, BUNDLE_ID) missing in .env – aborting build."
  exit 1
fi

#--------------------------------------
# Helper to call PlistBuddy
#--------------------------------------
plist_set_or_add() {
  local KEY_PATH="$1" VALUE="$2" TYPE="$3"
  /usr/libexec/PlistBuddy -c "Set :$KEY_PATH $VALUE" "$PLIST_FILE" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :$KEY_PATH $TYPE $VALUE" "$PLIST_FILE"
}

#--------------------------------------
# Inject bundle ID and team ID into xcconfig files
#--------------------------------------
inject_bundle_id_to_xcconfig() {
  local XCCONFIG_FILE="$1"
  local BUNDLE_ID_VALUE="$2"
  
  if [[ -f "$XCCONFIG_FILE" ]]; then
    # Use sed to replace BUNDLE_ID_PLACEHOLDER with actual bundle ID
    sed -i '' "s/BUNDLE_ID_PLACEHOLDER/$BUNDLE_ID_VALUE/g" "$XCCONFIG_FILE"
    echo "[inject_env] Injected bundle ID into $XCCONFIG_FILE"
  fi
}

# Inject bundle ID into xcconfig files
inject_bundle_id_to_xcconfig "$SRCROOT/Runner/Configs/AppInfo.xcconfig" "$BUNDLE_ID"

#--------------------------------------
# Inject bundle ID and team ID into project.pbxproj
#--------------------------------------
if [[ -f "$PROJECT_FILE" ]]; then
  # Use sed to replace BUNDLE_ID_PLACEHOLDER with actual bundle ID
  sed -i '' "s/BUNDLE_ID_PLACEHOLDER/$BUNDLE_ID/g" "$PROJECT_FILE"
  echo "[inject_env] Injected bundle ID into project.pbxproj"
  
  # Use sed to replace TEAM_ID_PLACEHOLDER with actual team ID (if available)
  if [[ -n "$TEAM_ID" ]]; then
    sed -i '' "s/TEAM_ID_PLACEHOLDER/$TEAM_ID/g" "$PROJECT_FILE"
    echo "[inject_env] Injected team ID into project.pbxproj"
  fi
fi

#--------------------------------------
# Inject values into Info.plist
#--------------------------------------
# Add Google client IDs if available
if [[ -n "$GID_CLIENT_ID" ]]; then
  plist_set_or_add "GIDClientID" "$GID_CLIENT_ID" "string"
fi

if [[ -n "$GID_SERVER_CLIENT_ID" ]]; then
  plist_set_or_add "GIDServerClientID" "$GID_SERVER_CLIENT_ID" "string"
fi

# CFBundleURLSchemes requires deletion then add to ensure a single correct entry
/usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLIST_FILE" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED_CLIENT_ID" "$PLIST_FILE"

echo "[inject_env] Successfully injected configuration values into macOS configuration files" 