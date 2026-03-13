---
name: linear-workflow
description: >
  Use this skill when a Linear issue exists for the current task, when one
  should be created, or when the user asks to interact with a Linear issue.
---

# Linear Workflow

Read this file fully before taking any action on a Linear issue.

---

## Tools

Use the `mcp__linear__*` tools (e.g. `mcp__linear__get_issue`, `mcp__linear__save_issue`). Always search before creating.

---

## The Agent's Role

The agent reads the issue, implements the work, commits, pushes, and updates the PR description. That's it.

**The agent never marks issues Done.** That is the user's step, triggered via `/done` after reviewing the work.

---

## When to Act on Linear

- A Linear issue ID is mentioned → read the issue fully before starting any work
- The user asks to create an issue → follow the creation rules below
- A significant unexpected blocker is hit → add a comment before stopping

Do not move issues through statuses (In Progress, In Review, etc.). The only status change that matters is Done, and that belongs to the user.

---

## Starting Work on an Issue

Read the issue carefully using `mcp__linear__get_issue`. Check whether it has a parent issue.

- **If it has a parent** — it is a subissue. The worktree already exists for the parent. Work within the current worktree; do not create a new one.
- **If it has no parent** — it is a top-level issue. The worktree was created by `start_issue.py` and the branch name is the issue ID.

Look for the `**Developer Comments:**` section before deciding on an approach. If there are notes asking for clarification, ask the user before proceeding.

---

## Scope Discipline

One meaningful change → one issue.

Do not split small, tightly related work into multiple issues, and do not create follow-up issues unless the work is truly separate. If it's covered by the same acceptance criteria, keep it in the same issue.

---

## Creating Issues

Only create an issue if one clearly doesn't exist yet. **Search first.**

### Title

- Verb-first, specific
- ✅ "Add logout button to profile screen"
- ❌ "Logout" / "Fix bug" / "Profile work"

### Description

```markdown
**What:** [one sentence on what this is]

**Why:** [why it's needed]

**Changes Required:**
- [ ] [file, module, or area that needs to change and what needs to happen]
- [ ] ...

**Acceptance Criteria:**
- [ ] ...
- [ ] ...

**Developer Comments:**
- [Leave this section as an empty bullet point by default. For human developer use only. Human devs can add notes here for the AI or other developers]
- ...

**Agent Comments:**
- [Leave this section as an empty bullet point by default. For AI use only. Reserved for the agent to leave comments. Use only when it adds real value — a blocker, a key decision, or a notable deviation from the original plan. Don't narrate normal progress. Keep this concise.]
- ...
```

### Required Fields

| Field | Rule |
| --- | --- |
| Title | Verb-first, specific |
| Description | What, why, acceptance criteria, developer comments, agent comments |
| Team | Always set |
| Priority | Set based on impact — don't leave blank |
| Label | At least one (`bug` / `feature` / `chore`) |

---

## Subissues

Use subissues when a large or complex problem requires multiple distinct steps or phases — each phase becomes its own issue, linked to a parent.

**When to use subissues:**

- The work spans multiple phases (e.g. refactor service → update controller → update tests)
- Each step could be committed and reviewed independently
- A single issue would have too many unrelated acceptance criteria

**When not to use subissues:**

- Small, tightly related changes that belong together
- Work already covered by a single set of acceptance criteria

### Creating Subissues

1. Create the parent issue first (broad scope, no code changes of its own)
2. Create each child issue with its own acceptance criteria
3. Link each child to the parent using `mcp__linear__sub_issue_write`

### Completing Subissues

All subissues share the parent's worktree and branch. When finished with a subissue, push the commits and update the PR description as normal, then remind the user to run `/done XCE-101` (with the subissue ID) to mark it Done. The worktree stays open.

Once the user has marked all subissues Done, they run `/done` (no argument, or with the parent issue ID) to mark the parent Done and close the worktree.

---

## What Not to Do

- Don't create issues for things already in scope of the current issue
- Don't move issues through statuses — the agent doesn't touch status
- Don't post comments just to say work is in progress
- Don't mark any issue Done — that is always the user's step via `/done`
