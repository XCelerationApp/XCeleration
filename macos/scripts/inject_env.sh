#!/usr/bin/env bash
# inject_env.sh – reads .env and writes required keys into the macOS Info.plist

set -euo pipefail

#--------------------------------------
# Paths
#--------------------------------------
# $SRCROOT points at macos/ by default when invoked by Xcode for a macOS target.
ENV_FILE="$SRCROOT/../.env"
PLIST_FILE="$SRCROOT/Runner/Info.plist"

#--------------------------------------
# Early exit when .env is absent
#--------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[inject_env] .env not found at $ENV_FILE – skipping plist injection."
  exit 0
fi

#--------------------------------------
# Parse required keys from .env
#--------------------------------------
REVERSED_CLIENT_ID=""

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
    GOOGLE_IOS_OAUTH_REVERSED_CLIENT_ID) REVERSED_CLIENT_ID="$VALUE" ;;
  esac
done < "$ENV_FILE"

# Validate presence
if [[ -z "$REVERSED_CLIENT_ID" ]]; then
  echo "[inject_env] Required key GOOGLE_IOS_OAUTH_REVERSED_CLIENT_ID missing in .env – aborting build."
  exit 1
fi

#--------------------------------------
# Inject values into Info.plist
#--------------------------------------
# CFBundleURLSchemes requires deletion then add to ensure a single correct entry
/usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLIST_FILE" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED_CLIENT_ID" "$PLIST_FILE"

echo "[inject_env] Successfully injected REVERSED_CLIENT_ID into macOS Info.plist" 