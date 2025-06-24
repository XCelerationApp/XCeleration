#!/usr/bin/env bash
# revert_env.sh – Resets plist values back to their committed state after a build.

set -euo pipefail

#--------------------------------------
# Paths and Placeholder
#--------------------------------------
PLIST_FILE="$SRCROOT/Runner/Info.plist"
PLACEHOLDER="TO_BE_REPLACED_BY_SCRIPT"

#--------------------------------------
# Helper to call PlistBuddy
#--------------------------------------
plist_set() {
  /usr/libexec/PlistBuddy -c "Set :$1 $2" "$3"
}

#--------------------------------------
# Revert Info.plist
#--------------------------------------
if [[ -f "$PLIST_FILE" ]]; then
    echo "[revert_env] Reverting macOS Info.plist"
    # This key has its value replaced, so we set it back to the placeholder.
    plist_set "CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLACEHOLDER" "$PLIST_FILE"
fi

echo "[revert_env] Successfully reverted macOS plist file." 