#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve flutter binary (mirrors logic in scripts/test_runner.py)
_find_flutter() {
  # 1. flutter on PATH
  if command -v flutter &>/dev/null; then flutter; return; fi
  # 2. Common relative layout: repo lives alongside flutter/
  local sibling="$(dirname "$REPO_ROOT")/flutter/bin/flutter"
  if [ -f "$sibling" ]; then echo "$sibling"; return; fi
  # 3. $HOME/flutter
  local home_flutter="$HOME/flutter/bin/flutter"
  if [ -f "$home_flutter" ]; then echo "$home_flutter"; return; fi
  # 4. Give up
  echo "flutter"
}

FLUTTER_BIN="$(_find_flutter)"

if ! "$FLUTTER_BIN" --version &>/dev/null; then
  echo "Error: flutter not found. Add flutter to PATH or install it alongside the repo." >&2
  exit 1
fi

# Resolve genhtml
if ! command -v genhtml &>/dev/null; then
  echo "Error: genhtml not found. Install lcov (e.g. brew install lcov / apt install lcov)." >&2
  exit 1
fi

echo "Running tests with coverage..."
$FLUTTER_BIN test --coverage --coverage-path "$REPO_ROOT/coverage/lcov.info"

echo "Generating HTML report..."
genhtml "$REPO_ROOT/coverage/lcov.info" \
  -o "$REPO_ROOT/coverage/html" \
  --title "XCeleration Test Coverage" \
  --quiet

REPORT="$REPO_ROOT/coverage/html/index.html"
echo "Done. Report at: $REPORT"

# Open the report if possible
if command -v open &>/dev/null; then        # macOS
  open "$REPORT"
elif command -v xdg-open &>/dev/null; then  # Linux
  xdg-open "$REPORT"
fi
