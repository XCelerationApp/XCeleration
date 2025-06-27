#!/usr/bin/env bash
# inject_env.sh – reads .env and writes required keys into Android build.gradle

set -euo pipefail

#--------------------------------------
# Paths
#--------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
BUILD_GRADLE_FILE="$SCRIPT_DIR/app/build.gradle"

#--------------------------------------
# Early exit when .env is absent
#--------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[inject_env] .env not found at $ENV_FILE – skipping Android injection."
  exit 0
fi

#--------------------------------------
# Parse required keys from .env
#--------------------------------------
BUNDLE_ID=""

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
    BUNDLE_ID) BUNDLE_ID="$VALUE" ;;
  esac
done < "$ENV_FILE"

# Validate presence
if [[ -z "$BUNDLE_ID" ]]; then
  echo "[inject_env] Required key BUNDLE_ID missing in .env – aborting build."
  exit 1
fi

#--------------------------------------
# Inject bundle ID into build.gradle
#--------------------------------------
if [[ -f "$BUILD_GRADLE_FILE" ]]; then
  # Use sed to replace BUNDLE_ID_PLACEHOLDER with actual bundle ID
  sed -i.bak "s/BUNDLE_ID_PLACEHOLDER/$BUNDLE_ID/g" "$BUILD_GRADLE_FILE"
  echo "[inject_env] Successfully injected BUNDLE_ID into Android build.gradle"
else
  echo "[inject_env] build.gradle not found at $BUILD_GRADLE_FILE"
  exit 1
fi 