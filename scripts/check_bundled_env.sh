#!/usr/bin/env bash
# Fails if the root .env — which pubspec.yaml bundles into the app as an asset,
# readable by anyone who unzips the build — contains build/signing secrets.
# Those belong in ios/fastlane/.env, which is never bundled.
#
# Usage: scripts/check_bundled_env.sh [path/to/.env]   (default: .env)
set -euo pipefail

env_file="${1:-.env}"
forbidden='^[[:space:]]*(export[[:space:]]+)?(APP_STORE_CONNECT_[A-Z0-9_]*|MATCH_PASSWORD|FASTLANE_[A-Z0-9_]*|MATCH_[A-Z0-9_]*|SUPABASE_SERVICE_ROLE_KEY)[[:space:]]*='

if [ ! -f "$env_file" ]; then
  echo "check_bundled_env: $env_file not found, nothing to check."
  exit 0
fi

if leaked=$(grep -E "$forbidden" "$env_file" | cut -d= -f1 | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//'); then
  echo "❌ $env_file is bundled into the app but contains build secrets:"
  echo "$leaked" | sed 's/^/   - /'
  echo "Move them to ios/fastlane/.env (see docs/09-ops/environment.md)."
  exit 1
fi

echo "✅ $env_file contains no build secrets."
