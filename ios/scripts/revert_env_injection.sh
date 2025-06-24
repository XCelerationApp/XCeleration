#!/usr/bin/env bash
# revert_env.sh – Resets plist values back to their committed state after a build.

set -euo pipefail

#--------------------------------------
# Paths and Placeholder
#--------------------------------------
INFO_PLIST="$SRCROOT/Runner/Info.plist"
GOOGLE_PLIST="$SRCROOT/Runner/GoogleService-Info.plist"
PLACEHOLDER="TO_BE_REPLACED_BY_SCRIPT"

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
# Revert Info.plist
#--------------------------------------
if [[ -f "$INFO_PLIST" ]]; then
  echo "[revert_env] Reverting Info.plist"
  # These keys are added by the inject script, so we remove them to match the committed file.
  plist_delete "GIDClientID" "$INFO_PLIST"
  plist_delete "GIDServerClientID" "$INFO_PLIST"

  # This key has its value replaced, so we set it back to the placeholder.
  plist_set "CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLACEHOLDER" "$INFO_PLIST"
fi

#--------------------------------------
# Revert GoogleService-Info.plist
#--------------------------------------
if [[ -f "$GOOGLE_PLIST" ]]; then
  echo "[revert_env] Reverting GoogleService-Info.plist"
  # These keys have their values replaced, so we set them back to the placeholder.
  plist_set "CLIENT_ID" "$PLACEHOLDER" "$GOOGLE_PLIST"
  plist_set "REVERSED_CLIENT_ID" "$PLACEHOLDER" "$GOOGLE_PLIST"
fi

echo "[revert_env] Successfully reverted plist files." 