#!/usr/bin/env bash
# inject_env.sh – reads .env and writes required keys into Info.plist
# This script is intended to be called from an Xcode "Run Script" build phase.
# It makes the .env file the single source of truth for both Dart runtime and
# native-side values required at compile time.

set -euo pipefail

#--------------------------------------
# Paths
#--------------------------------------
# $SRCROOT points at ios/ by default when invoked by Xcode.
ENV_FILE="$SRCROOT/../.env"
PLIST_FILE="$SRCROOT/Runner/Info.plist"

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

  # Trim whitespace and quotes from VALUE
  VALUE=$(echo "$VALUE" | xargs | tr -d "'\"")

  case "$KEY" in
    GOOGLE_IOS_OAUTH_CLIENT_ID) GID_CLIENT_ID="$VALUE" ;;
    GOOGLE_IOS_OAUTH_REVERSED_CLIENT_ID) REVERSED_CLIENT_ID="$VALUE" ;;
    GOOGLE_WEB_OAUTH_CLIENT_ID) GID_SERVER_CLIENT_ID="$VALUE" ;;
  esac
done < "$ENV_FILE"

# Validate presence
if [[ -z "$GID_CLIENT_ID" || -z "$REVERSED_CLIENT_ID" || -z "$GID_SERVER_CLIENT_ID" ]]; then
  echo "[inject_env] Required keys missing in .env – aborting build."
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
# Inject values into Info.plist
#--------------------------------------
plist_set_or_add "GIDClientID" "$GID_CLIENT_ID" "string"
plist_set_or_add "GIDServerClientID" "$GID_SERVER_CLIENT_ID" "string"

# CFBundleURLSchemes requires deletion then add to ensure a single correct entry
/usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLIST_FILE" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED_CLIENT_ID" "$PLIST_FILE"

echo "[inject_env] Successfully injected GID_CLIENT_ID, REVERSED_CLIENT_ID, and GID_SERVER_CLIENT_ID into Info.plist"

#--------------------------------------
# Inject values into GoogleService-Info.plist
#--------------------------------------
GOOGLE_SERVICES_PLIST_FILE="$SRCROOT/Runner/GoogleService-Info.plist"
if [[ -f "$GOOGLE_SERVICES_PLIST_FILE" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CLIENT_ID $GID_CLIENT_ID" "$GOOGLE_SERVICES_PLIST_FILE"
  /usr/libexec/PlistBuddy -c "Set :REVERSED_CLIENT_ID $REVERSED_CLIENT_ID" "$GOOGLE_SERVICES_PLIST_FILE"
  echo "[inject_env] Successfully injected keys into GoogleService-Info.plist"
else
  echo "[inject_env] GoogleService-Info.plist not found, skipping."
fi 