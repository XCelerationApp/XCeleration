Mark a Linear issue as Done. If an issue ID is passed (e.g. `/done XCE-101`), use that. Otherwise use the worktree's primary issue from `.linear-issue`.

Follow these steps in order:

## 1. Identify the issue

If `$ARGUMENTS` contains an issue ID, use it. Otherwise run `cat .linear-issue` to get the worktree's primary issue ID.

## 2. Check everything is pushed

Run both:
- `git status` — confirm no uncommitted or unstaged changes
- `git log origin/$(git branch --show-current)..HEAD` — confirm no unpushed commits

If either check fails, stop and tell the user exactly what is unfinished before going any further.

## 3. Mark the issue as Done

Use `mcp__linear__save_issue` to set the status to Done.

## 4. Check if this is a subissue

Fetch the issue using `mcp__linear__get_issue`. Check whether it has a parent issue.

- **If it has a parent** → it is a subissue. Tell the user it's marked Done and **stop here**. Do not touch the worktree or Cursor.
- **If it has no parent** → it is a top-level issue. Continue to step 5.

## 5. Remove the worktree

Get the issue number from the issue ID (e.g. `XCE-123` → `123`) and run:
```bash
MAIN=$(dirname $(git rev-parse --git-common-dir))
python3 "$MAIN/scripts/remove_worktree.py" <number>
```

This handles simulator cleanup and worktree removal in one step.

## 6. Confirm to the user

Tell the user:
- The issue has been marked Done
- The local worktree has been removed
- Close the Cursor window for this issue manually
- The branch and PR on GitHub remain open for review and merging
