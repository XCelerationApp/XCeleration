---
name: git-workflow
description: >
  Use this skill when the user asks to commit changes, create a branch,
  open a pull request, or update a PR description.
---

# Git & PR Workflow

Read this file fully before taking any git or PR action.

---

## Branch Naming

| Type | Format | Example |
| --- | --- | --- |
| Feature | `feat/<short-description>` | `feat/add-logout-button` |
| Bug fix | `fix/<short-description>` | `fix/timer-overflow` |
| Refactor | `refactor/<short-description>` | `refactor/timing-data-di` |
| Docs / skills | `docs/<short-description>` | `docs/update-skill-files` |
| Chore | `chore/<short-description>` | `chore/update-dependencies` |

- Use lowercase kebab-case
- Be specific — `fix/race-result-sort-order` not `fix/bug`
- Branch off `dev` unless told otherwise

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

Use the right tool for the job:

| Operation | Tool |
| --- | --- |
| List PRs / find PR number | `gh pr list --head <branch>` (Bash) |
| Read PR details | `gh pr view <number>` (Bash) |
| Update PR description or title | `mcp__github__update_pull_request` |
| Add a PR comment | `mcp__github__add_issue_comment` |

### Flow

1. Create a branch from `dev`
2. Make commits (one concern per commit)
3. Push: `git push -u origin <branch-name>`
4. A PR is **automatically created** — do not create one manually
   - The PR may take a few seconds to appear; wait then run `gh pr list --head <branch-name>` to confirm it exists and get the PR number
5. Update the PR description using: `mcp__github__update_pull_request`
6. **Verify** the description was applied: `gh pr view <number> --json body -q .body`
   - If the body still shows the auto-generated text, re-run step 5

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
- Don't create PRs manually — they are auto-created on push
- Don't amend published commits
- Don't push to `main`
