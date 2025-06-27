#!/usr/bin/env bash
# revert_env_injection.sh – Resets Android build.gradle values back to their committed state after a build.

set -euo pipefail

#--------------------------------------
# Paths
#--------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
BUILD_GRADLE_FILE="$SCRIPT_DIR/app/build.gradle"
BUNDLE_ID_PLACEHOLDER="BUNDLE_ID_PLACEHOLDER"

#--------------------------------------
# Helper to revert build.gradle
#--------------------------------------
revert_bundle_id_in_gradle() {
  if [[ -f "$BUILD_GRADLE_FILE" && -f "$ENV_FILE" ]]; then
    # Extract the bundle ID from .env to replace it back with placeholder
    BUNDLE_ID=$(grep "^BUNDLE_ID" "$ENV_FILE" | cut -d'=' -f2 | xargs | tr -d "'\"")
    if [[ -n "$BUNDLE_ID" ]]; then
      sed -i.bak "s/$BUNDLE_ID/$BUNDLE_ID_PLACEHOLDER/g" "$BUILD_GRADLE_FILE"
      # Remove backup file
      rm -f "$BUILD_GRADLE_FILE.bak"
      echo "[revert_env] Reverted bundle ID in Android build.gradle"
    fi
  fi
}

#--------------------------------------
# Revert build.gradle
#--------------------------------------
revert_bundle_id_in_gradle

echo "[revert_env] Successfully reverted Android build.gradle." 