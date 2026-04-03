#!/usr/bin/env bash
# disk_cleanup.sh — Analyze disk usage and suggest cleanup commands for dev machines.
# Usage: bash scripts/disk_cleanup.sh

set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

printf "${BOLD}=== Disk Usage Report ===${RESET}\n\n"

# Current free space
avail=$(df -h / | awk 'NR==2 {print $4}')
capacity=$(df -h / | awk 'NR==2 {print $5}')
printf "${BOLD}Free space:${RESET} %s (%s used)\n\n" "$avail" "$capacity"

# Collect candidates: (size_bytes, label, path, safe_to_delete)
declare -a candidates=()
declare -a labels=()
declare -a paths=()
declare -a safety=()
idx=0

add_candidate() {
    local dir="$1" label="$2" safe="$3"
    if [ -d "$dir" ]; then
        local size_hr size_bytes
        size_hr=$(du -sh "$dir" 2>/dev/null | cut -f1 || true)
        size_bytes=$(du -sk "$dir" 2>/dev/null | cut -f1 || true)
        size_bytes="${size_bytes:-0}"
        if [ "$size_bytes" -gt 102400 ] 2>/dev/null; then  # >100 MB
            candidates[$idx]="$size_bytes"
            labels[$idx]="$label ($size_hr)"
            paths[$idx]="$dir"
            safety[$idx]="$safe"
            idx=$((idx + 1))
        fi
    fi
}

printf "${BOLD}Scanning common locations...${RESET}\n"

# Xcode
add_candidate "$HOME/Library/Developer/Xcode/DerivedData" \
    "Xcode DerivedData (build caches)" "safe"
add_candidate "$HOME/Library/Developer/Xcode/iOS DeviceSupport" \
    "Xcode iOS DeviceSupport (device symbols)" "safe"
add_candidate "$HOME/Library/Developer/Xcode/watchOS DeviceSupport" \
    "Xcode watchOS DeviceSupport" "safe"
add_candidate "$HOME/Library/Developer/Xcode/Archives" \
    "Xcode Archives (old .xcarchive builds)" "review"

# Simulators
add_candidate "$HOME/Library/Developer/CoreSimulator/Devices" \
    "iOS Simulators" "review"
add_candidate "$HOME/Library/Developer/CoreSimulator/Caches" \
    "Simulator Caches" "safe"

# CocoaPods
add_candidate "$HOME/.cocoapods/repos" \
    "CocoaPods repo cache" "safe"
add_candidate "$HOME/Library/Caches/CocoaPods" \
    "CocoaPods download cache" "safe"

# Flutter
add_candidate "$HOME/Library/Developer/flutter" \
    "Flutter cache" "safe"
# Flutter SDK cache (pub, artifacts)
if [ -n "${FLUTTER_ROOT:-}" ] && [ -d "$FLUTTER_ROOT/bin/cache" ]; then
    add_candidate "$FLUTTER_ROOT/bin/cache" \
        "Flutter SDK cache (artifacts)" "review"
fi
# Also check common Flutter locations
for fdir in "$HOME/Programming_project/flutter/bin/cache" "$HOME/flutter/bin/cache" "$HOME/development/flutter/bin/cache"; do
    add_candidate "$fdir" "Flutter SDK cache (artifacts)" "review"
done

# Pub cache
add_candidate "$HOME/.pub-cache" \
    "Dart pub cache (downloaded packages)" "review"

# Gradle (Android)
add_candidate "$HOME/.gradle/caches" \
    "Gradle caches" "safe"
add_candidate "$HOME/.gradle/wrapper/dists" \
    "Gradle wrapper distributions" "safe"

# npm / yarn / pnpm
add_candidate "$HOME/.npm" "npm cache" "safe"
add_candidate "$HOME/Library/Caches/Yarn" "Yarn cache" "safe"
add_candidate "$HOME/Library/pnpm" "pnpm store" "safe"

# Homebrew
add_candidate "$(brew --cache 2>/dev/null || echo '/nonexistent')" \
    "Homebrew download cache" "safe"

# Trash
add_candidate "$HOME/.Trash" "Trash" "safe"

# Docker
add_candidate "$HOME/Library/Containers/com.docker.docker/Data" \
    "Docker data" "review"

# Xcode Caches
add_candidate "$HOME/Library/Caches/com.apple.dt.Xcode" \
    "Xcode caches" "safe"

# System logs
add_candidate "$HOME/Library/Logs" "User logs" "review"

printf "\n"

if [ $idx -eq 0 ]; then
    printf "${GREEN}No large cleanup candidates found (>100 MB). Disk looks tidy!${RESET}\n"
    exit 0
fi

# Sort by size descending (simple bubble sort for portability)
for ((i = 0; i < idx; i++)); do
    for ((j = i + 1; j < idx; j++)); do
        if [ "${candidates[$j]}" -gt "${candidates[$i]}" ]; then
            tmp="${candidates[$i]}"; candidates[$i]="${candidates[$j]}"; candidates[$j]="$tmp"
            tmp="${labels[$i]}"; labels[$i]="${labels[$j]}"; labels[$j]="$tmp"
            tmp="${paths[$i]}"; paths[$i]="${paths[$j]}"; paths[$j]="$tmp"
            tmp="${safety[$i]}"; safety[$i]="${safety[$j]}"; safety[$j]="$tmp"
        fi
    done
done

printf "${BOLD}%-4s  %-55s  %s${RESET}\n" "#" "Location" "Safety"
printf "%-4s  %-55s  %s\n" "---" "-------" "------"

for ((i = 0; i < idx; i++)); do
    n=$((i + 1))
    if [ "${safety[$i]}" = "safe" ]; then
        tag="${GREEN}safe to delete${RESET}"
    else
        tag="${YELLOW}review first${RESET}"
    fi
    printf "%-4s  %-55s  %b\n" "$n." "${labels[$i]}" "$tag"
done

printf "\n${BOLD}Suggested cleanup commands:${RESET}\n\n"

for ((i = 0; i < idx; i++)); do
    dir="${paths[$i]}"
    label="${labels[$i]}"

    # Special-case commands for certain directories
    case "$dir" in
        *CoreSimulator/Devices)
            printf "${CYAN}# %s${RESET}\n" "$label"
            printf "xcrun simctl delete unavailable\n\n"
            ;;
        */.Trash)
            printf "${CYAN}# %s${RESET}\n" "$label"
            printf "rm -rf ~/.Trash/*\n\n"
            ;;
        */.npm)
            printf "${CYAN}# %s${RESET}\n" "$label"
            printf "npm cache clean --force\n\n"
            ;;
        */Caches/Yarn)
            printf "${CYAN}# %s${RESET}\n" "$label"
            printf "yarn cache clean\n\n"
            ;;
        */brew/*)
            printf "${CYAN}# %s${RESET}\n" "$label"
            printf "brew cleanup --prune=all\n\n"
            ;;
        *)
            printf "${CYAN}# %s${RESET}\n" "$label"
            printf "rm -rf \"%s\"\n\n" "$dir"
            ;;
    esac
done

printf "${BOLD}Tip:${RESET} Run only the 'safe to delete' commands without worry.\n"
printf "     For 'review first' items, check contents before deleting.\n"
