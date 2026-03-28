#!/bin/bash
# Launch the Flutter app on this worktree's paired simulator.
# Reads the simulator UDID from .simulator_udid at the repo root.
# Any extra arguments are forwarded to `flutter run`.
#
# Usage: scripts/run.sh [flutter run flags...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_ROOT="$(dirname "$SCRIPT_DIR")"
UDID_FILE="$WORKTREE_ROOT/.simulator_udid"

if [ ! -f "$UDID_FILE" ]; then
    echo "Error: .simulator_udid not found at $UDID_FILE"
    echo "Run scripts/start_issue.py to create a paired simulator, or create the file manually."
    exit 1
fi

UDID=$(tr -d '[:space:]' < "$UDID_FILE")

if [ -z "$UDID" ]; then
    echo "Error: .simulator_udid is empty"
    exit 1
fi

echo "Running on simulator: $UDID"
exec flutter run -d "$UDID" "$@"
