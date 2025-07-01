#!/bin/bash

# Git Sync & Cleanup Script
# Prevents synchronization issues by keeping local repo in sync with remote

echo "🔄 Starting Git sync and cleanup..."

# 1. Fetch latest changes and prune deleted remote branches
echo "📡 Fetching latest changes and pruning deleted remotes..."
git fetch --all --prune

# 2. Update main branch
echo "🌟 Syncing main branch..."
current_branch=$(git branch --show-current)
git checkout main >/dev/null 2>&1
git pull origin main

# 3. Update dev branch  
echo "🚀 Syncing dev branch..."
git checkout dev >/dev/null 2>&1
git pull origin dev

# 4. Clean up stale branches that track deleted remotes
echo "🧹 Cleaning up stale branches..."
stale_branches=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | grep '\[gone\]' | awk '{print $1}')
if [ -n "$stale_branches" ]; then
    echo "Found stale branches: $stale_branches"
    echo "$stale_branches" | xargs git branch -D 2>/dev/null || true
    echo "✅ Cleaned up stale branches"
else
    echo "✅ No stale branches found"
fi

# 5. Return to original branch
git checkout "$current_branch" >/dev/null 2>&1

# 6. Show current status
echo ""
echo "📊 Current repository status:"
echo "📍 Current branch: $(git branch --show-current)"
echo "📈 Main branch: $(git log --oneline -1 main)"
echo "🚀 Dev branch: $(git log --oneline -1 dev)"

# 7. Check if current branch needs sync
if git status | grep -q "Your branch is behind"; then
    echo "⚠️  Your current branch is behind its remote. Consider running: git pull"
fi

echo ""
echo "✅ Git sync completed successfully!" 