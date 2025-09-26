#!/usr/bin/env bash
# inject_env.sh – reads .env and writes required keys into Info.plist and project configuration
# This script is intended to be called from an Xcode "Run Script" build phase.
# It makes the .env file the single source of truth for both Dart runtime and
# native-side values required at compile time.

set -euo pipefail

# Skip if running from fastlane (fastlane handles injection itself)
if [[ "${FASTLANE_BUILD:-}" == "true" ]]; then
  echo "[inject_env] Skipping injection - running from fastlane"
  exit 0
fi

# Skip during Analyze/Clean actions to avoid non-build failures
if [[ "${ACTION:-}" == "analyze" || "${ACTION:-}" == "clean" ]]; then
  echo "[inject_env] Skipping during action: ${ACTION:-unknown}"
  exit 0
fi

#--------------------------------------
# Paths
#--------------------------------------
# $SRCROOT points at ios/ by default when invoked by Xcode.
ENV_FILE="$SRCROOT/../.env"
PLIST_FILE="$SRCROOT/Runner/Info.plist"
PROJECT_FILE="$SRCROOT/Runner.xcodeproj/project.pbxproj"
FLAG_FILE="${DERIVED_FILE_DIR:-$SRCROOT}/env_injection_applied.flag"
PLACEHOLDER="TO_BE_REPLACED_BY_SCRIPT"

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

# Validate presence (non-fatal: skip injection if incomplete)
if [[ -z "$GID_CLIENT_ID" || -z "$REVERSED_CLIENT_ID" || -z "$GID_SERVER_CLIENT_ID" || -z "$BUNDLE_ID" || -z "$TEAM_ID" ]]; then
  echo "[inject_env] Required keys missing in .env – skipping injection."
  exit 0
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
# Inject bundle ID and team ID into project.pbxproj (only if placeholders exist)
#--------------------------------------
if [[ -f "$PROJECT_FILE" ]]; then
  if grep -q "BUNDLE_ID_PLACEHOLDER" "$PROJECT_FILE"; then
    sed -i '' "s/BUNDLE_ID_PLACEHOLDER/$BUNDLE_ID/g" "$PROJECT_FILE"
    echo "[inject_env] Injected bundle ID into project.pbxproj"
    touch "$FLAG_FILE" || true
  else
    echo "[inject_env] Skipping bundle ID injection – no placeholder present"
  fi
  if grep -q "TEAM_ID_PLACEHOLDER" "$PROJECT_FILE"; then
    sed -i '' "s/TEAM_ID_PLACEHOLDER/$TEAM_ID/g" "$PROJECT_FILE"
    echo "[inject_env] Injected team ID into project.pbxproj"
    touch "$FLAG_FILE" || true
  else
    echo "[inject_env] Skipping team ID injection – no placeholder present"
  fi
fi

#--------------------------------------
# Inject values into Info.plist (only when placeholder is present)
#--------------------------------------
CURRENT_SCHEME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLIST_FILE" 2>/dev/null || echo "")
if [[ "$CURRENT_SCHEME" == "$PLACEHOLDER" || -z "$CURRENT_SCHEME" ]]; then
  plist_set_or_add "GIDClientID" "$GID_CLIENT_ID" "string"
  plist_set_or_add "GIDServerClientID" "$GID_SERVER_CLIENT_ID" "string"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLIST_FILE" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED_CLIENT_ID" "$PLIST_FILE"
  touch "$FLAG_FILE" || true
  echo "[inject_env] Injected keys into Info.plist"
else
  echo "[inject_env] Skipping Info.plist injection – existing scheme detected"
fi

#--------------------------------------
# Inject values into GoogleService-Info.plist
#--------------------------------------
GOOGLE_SERVICES_PLIST_FILE="$SRCROOT/Runner/GoogleService-Info.plist"
if [[ -f "$GOOGLE_SERVICES_PLIST_FILE" ]]; then
  CURRENT_GSERV_CLIENT=$(/usr/libexec/PlistBuddy -c "Print :CLIENT_ID" "$GOOGLE_SERVICES_PLIST_FILE" 2>/dev/null || echo "")
  if [[ "$CURRENT_GSERV_CLIENT" == "$PLACEHOLDER" || -z "$CURRENT_GSERV_CLIENT" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CLIENT_ID $GID_CLIENT_ID" "$GOOGLE_SERVICES_PLIST_FILE"
    /usr/libexec/PlistBuddy -c "Set :REVERSED_CLIENT_ID $REVERSED_CLIENT_ID" "$GOOGLE_SERVICES_PLIST_FILE"
    touch "$FLAG_FILE" || true
    echo "[inject_env] Injected keys into GoogleService-Info.plist"
  else
    echo "[inject_env] Skipping GoogleService-Info.plist injection – existing values detected"
  fi
else
  echo "[inject_env] GoogleService-Info.plist not found, skipping."
fi