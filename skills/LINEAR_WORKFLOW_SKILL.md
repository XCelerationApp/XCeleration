---
name: linear-workflow
description: >
  Use this skill when a Linear issue exists for the current task, when one
  should be created, or when the user asks to interact with a Linear issue.
---

# Linear Workflow

Keep it simple. The most important rule is: **mark issues Done when work is complete.**

Read this file fully before taking any action on a Linear issue.

---

## Tools

Use the `mcp__linear__*` tools (e.g. `mcp__linear__get_issue`, `mcp__linear__save_issue`,
`mcp__linear__create_comment`). Always search before creating.

---

## When to Act on Linear

- A Linear issue ID is mentioned (e.g. XCE-123) → reference it in your work
- The user asks to create an issue → follow the creation rules below
- Work on a task is finished → mark the issue Done
- A significant unexpected blocker is hit → add a comment before stopping

For trivial tasks, don't move through every status. A small fix doesn't need
In Progress → In Review → Done. Just mark it Done when it's done.

---

## Marking Issues Done

This is the most important step and the easiest to forget.

Done means:

- Code merged or finalized
- Tests passing
- No known regressions
- The user has not flagged unresolved concerns

Do not mark Done based on local completion alone if the work hasn't been merged.

---

## Scope Discipline

One meaningful change → one issue.

Do not split small, tightly related work into multiple issues, and do not create
follow-up issues unless the work is truly separate. If it's covered by the same
acceptance criteria, keep it in the same issue.

---

## Creating Issues

Only create an issue if one clearly doesn't exist yet. **Search first.** If it's
unclear whether an issue already exists, ask before creating.

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

## Acting on Issues

### Before working with a Linear issue

Read the issue carefully and in-depth. Especially look for the `**Developer Comments:**` section and read any notes before deciding on an approach. If the notes say to ask the user for clarification, be sure to do this when instructed.

### Working on the Issue

Use skills/REFACTORING_SKILL.md to refactor the code as described in the issue.

---

## What Not to Do

- Don't create issues for things already in scope of the current issue
- Don't move issues through every status for simple tasks
- Don't post comments just to say work is in progress
- Don't mark Done if tests are failing
