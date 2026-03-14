---
name: git-workflow
description: >
  Use this skill when the user asks to commit changes, create a branch,
  open a pull request, or update a PR description.
---

# Git & PR Workflow

Read this file fully before taking any git or PR action.

---

## Branches

Each issue gets its own git worktree, created by running `python3 scripts/start_issue.py XCE-123` from the main repo. The branch name is the Linear issue ID (e.g. `XCE-123`), branched from `dev`.

Do not create branches manually. If no worktree exists yet, ask the user to run the start script first.

---

## Commits

### Format

```markdown
Type - Short description of what changed and why

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### Types

| Type | When to use |
| --- | --- |
| `Feat` | New feature or behaviour |
| `Fix` | Bug fix |
| `Refactor` | Code change with no behaviour change |
| `Docs` | Documentation or skill file changes |
| `Chore` | Tooling, formatting, dependency updates |
| `Test` | Adding or updating tests |

### Rules

- **One concern per commit** — don't bundle unrelated changes
- Stage specific files by name, never `git add .` or `git add -A`
- Always pass the commit message via heredoc to preserve formatting:

```sh
git commit -m "$(cat <<'EOF'
Type - Description of change

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Pull Requests

### GitHub Tool Reference

| Operation | Tool |
| --- | --- |
| List PRs / find PR number | `gh pr list --head <branch>` (Bash) |
| Read PR details | `gh pr view <number>` (Bash) |
| Update PR description or title | `mcp__github__update_pull_request` |
| Add a PR comment | `mcp__github__add_issue_comment` |

### Flow

1. Make commits (one concern per commit)
2. Push: `git push -u origin <branch-name>`
3. A PR is **automatically created** — never create one manually unless the user explicitly asks
   - Wait a few seconds, then run `gh pr list --head <branch-name>` to confirm it exists and get the PR number
   - If the auto-created PR does not appear after waiting, check again before considering any other action (this could take up to 30s)
4. **Only update the PR title and description after all commits are pushed.** GitHub wipes any custom description on each push — set it once, at the very end.
5. Fetch the Linear issue title using `mcp__linear__get_issue`, then update the PR title and description together using `mcp__github__update_pull_request`:
   - **Title:** `Type - <Linear issue title>` (e.g. `Feat - Add logout button to profile screen`)
   - **Body:** see PR Description Format below
6. **Verify** both were applied: `gh pr view <number> --json title,body -q '{title:.title,body:.body}'`
   - If either still shows auto-generated content, re-run step 5

**This is where the agent's job ends.** Tell the user the PR is ready for review, and remind them:

- For a subissue: run `/done XCE-101` to mark it Done (worktree stays open for remaining subissues)
- For a top-level issue: run `/done` to mark it Done and clean up the worktree

### PR Description Format

```markdown
## Summary
- [bullet point summary of what changed and why]
- ...

## Test plan
- [ ] [what to manually verify or what tests to run]
- [ ] ...

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Rules

- Base branch is always `dev` (not `main`)
- Keep the title short and in the same format as commits: `Type - Description`
- Do not push to `main` directly
- Do not force-push unless the user explicitly asks

---

## What Not to Do

- Don't `git add .` — stage files explicitly
- Don't skip `Co-Authored-By` in commit messages
- Don't create branches or PRs manually — branches come from the start script, PRs are auto-created on push
- Don't amend published commits
- Don't push to `main`
- Don't mark Linear issues Done — that is always the user's step via `/done`
