# Merge Conflict Resolution — Design Plan

## Overview

After a merge recording session, conflicts may arise where bib numbers entered don't cleanly map to runners in the database. This screen guides the recorder through resolving every conflict before results are committed. Every finish position must end with a real, identified runner — no unknown/unidentified state is allowed.

---

## Conflict Types

### 1. Unknown Bib

A bib number was entered that does not match any runner in the database.

**Likely cause:** The coach forgot to add a runner before the race.

**Resolution options:**

- Assign to an existing unassigned runner (picked from a sorted proximity list)
- Create a new runner (permanently added to the database)

### 2. Duplicate Bib

The same bib number appears at two different finish positions.

**Likely cause:** The recorder entered the same bib twice — one is correct, one is a typo.

**Resolution flow (two steps, handled inline):**

1. Show both occurrences side by side. The recorder picks which finish position is the correct one — that entry is unflagged immediately.
2. The other entry now becomes an Unknown Bib conflict and is resolved inline before moving on (assign to existing runner or create new runner).

**Important constraint:** If creating a new runner for the "wrong" duplicate entry, they must be given a new unique bib number — the duplicate bib cannot be reused.

---

## Resolution Options (for both conflict types)

### Assign to Existing Unassigned Runner

- Shows a list of runners in the database who have not yet been assigned a finish position in this race
- Sorted by numeric proximity to the entered bib number (e.g. entered 412 → shows 410, 411, 413, 414...)
- Displays: bib number, runner name, proximity delta

### Create New Runner

- Opens a form to create a new runner
- Requires a new unique bib number (cannot reuse the conflicting bib in the duplicate case)
- Runner is permanently saved to the team database — not a one-off assignment

---

## Conflict Ordering

1. **Duplicates first** — resolved inline (both steps) before moving on, since resolving a duplicate naturally produces an unknown that must be resolved immediately
2. **Remaining unknowns second** — any standalone unknown bibs not produced by duplicate resolution
3. Within each group, ordered by **finish position** (earliest finisher first)

---

## UX Principles

### One Conflict at a Time

Show a single conflict card. Resolve it, then move to the next. Avoids overwhelming the recorder.

### Progress Indicator

A persistent indicator at the top of the screen (e.g. "3 of 7 conflicts resolved") keeps the recorder oriented.

### Go Back

Resolutions are not final until the recorder hits a final confirmation/submit screen. They can navigate back and change earlier decisions.

### Duplicate Side-by-Side View

For duplicates, both occurrences are shown side by side with:

- Finish position
- Bib number
- Finish time

This lets the recorder quickly compare ("position 14 finished 4 seconds before position 22 — that tracks") and pick the correct one.

### Completion State

A clear "All conflicts resolved" screen is shown before final submission, giving the recorder a moment to confirm before committing results.

---

## Race Context Panel

Available on every conflict card. Helps the recorder identify a runner by seeing who finished around them (e.g. "the runner ahead was Bill Smith — I can ask him who was just behind").

### Default View (collapsed)

- Runner immediately ahead of the conflict position: name, bib, finish time
- Runner immediately behind the conflict position: name, bib, finish time

### Expanded View ("See more")

- A wider window of finish positions around the conflict (~5 either side, or the full list)
- Read-only throughout — no actions can be taken from the context panel
