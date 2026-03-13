Mark a Linear issue as Done. If an issue ID is passed (e.g. `/done XCE-101`), use that. Otherwise use the worktree's primary issue from `.linear-issue`.

Follow these steps in order:

## 1. Identify the issue

If `$ARGUMENTS` contains an issue ID, use it. Otherwise run `cat .linear-issue` to get the worktree's primary issue ID.

## 2. Check everything is pushed

Run both:
- `git status` — confirm no uncommitted or unstaged changes
- `git log origin/$(git branch --show-current)..HEAD` — confirm no unpushed commits

If either check fails, stop and tell the user exactly what is unfinished before going any further.

## 3. Check if this is a subissue

Fetch the issue using `mcp__linear__get_issue`. Check whether it has a parent issue.

- **If it has a parent** → it is a subissue. Mark it Done (`mcp__linear__save_issue`), tell the user it's marked Done, and **stop here**. Do not touch the worktree or Cursor.
- **If it has no parent** → it is a top-level issue. Continue to step 4.

## 4. Mark the issue as Done

Use `mcp__linear__save_issue` to set the status to Done.

## 5. Remove the local worktree

Get the paths:
```bash
WORKTREE=$(git rev-parse --show-toplevel)
MAIN=$(dirname $(git rev-parse --git-common-dir))
```

Remove the worktree from the main repo:
```bash
git -C "$MAIN" worktree remove "$WORKTREE" --force
```

## 6. Close the Cursor window

Close the Cursor window using the issue ID from the worktree folder name:
```bash
osascript -e "tell application \"Cursor\" to close (every window whose name contains \"$ISSUE_ID\")"
```

If the osascript command errors or no matching window is found, skip silently.

## 7. Confirm to the user

Tell the user:
- The issue has been marked Done
- The local worktree has been removed
- The Cursor window has been closed
- The branch and PR on GitHub remain open for review and merging
