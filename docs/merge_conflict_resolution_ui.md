# Merge Conflict Resolution — UI Screens

> References existing components from `lib/core/components/` and established screen patterns.

## Screen Flow Overview

```
Conflict Summary
      │
      ▼
Duplicate Conflict Card  ──►  Inline Unknown Resolution  ─┐
      │                                                    │
      │ (all duplicates done)                              │
      ▼                                                    │
Unknown Bib Conflict Card ◄────────────────────────────────┘
      │
      │ (all conflicts done)
      ▼
Completion Screen
```

Each conflict card shares a common shell (progress indicator, race context panel). Only the card body changes per conflict type.

---

## 1. Conflict Summary Screen

**When shown:** Entry point before any conflict is resolved.

**Layout:**

- `GlassCard` containing:
  - `SectionHeaderWidget` — title "Resolve Merge Conflicts", subtitle with conflict breakdown (e.g. "2 duplicate bibs · 3 unknown bibs")
  - Two `ConflictButton` cards (one per conflict type) — read-only summary mode, showing count and brief description of each type
  - `FullWidthButton` (primary) — "Start Resolving"

**Notes:** `ConflictButton` already exists in `race_components.dart` and is designed for exactly this kind of conflict entry point.

---

## 2. Conflict Card Shell (shared)

Every conflict card (Sections 3, 4, 5) is wrapped in this shared shell.

**Top of screen:**

- Linear progress indicator + text label — "3 of 7 resolved"
- Back `CircleIconButton` (top-left) — navigates to the previous conflict

**Card:**

- `GlassCard` wrapping the conflict-specific body

**Bottom of card:**

- Race Context Panel (see Section 7) — collapsed by default

---

## 3. Duplicate Conflict Card

**When shown:** First group of conflicts, one card per duplicate bib.

**Card body:**

- `SectionHeaderWidget` — title "Duplicate Bib", subtitle "Which finish position actually had Bib #412?"
- Two `GlassCard` tiles shown side by side (or stacked on narrow screens), each displaying:
  - Finish position (large, prominent)
  - Finish time
  - `PrimaryButton` — "This one is correct"

**On selection:**

- Chosen tile gets a visual confirmation state (checkmark, green tint)
- Card body transitions inline to the Inline Unknown Resolution step (Section 4) — no navigation

---

## 4. Inline Unknown Resolution (post-duplicate)

**When shown:** Immediately after the recorder picks the correct duplicate entry. Replaces the duplicate card body in place. Progress does not increment yet.

**Card body:**

- `SectionHeaderWidget` — title "Fix the other entry", subtitle showing the finish position and time of the "wrong" entry

**Two sections within the card:**

### Option A — Assign to existing runner

- `SectionHeaderWidget` (compact) — "Nearby unassigned runners"
- `ListView` of `StandardListItem` rows, each showing:
  - Leading: bib number chip
  - Title: runner name
  - Subtitle: proximity delta (e.g. "3 away")
  - Trailing: `CircleIconButton` with a checkmark to select
- Sorted by numeric proximity to the original bib

### Option B — Create new runner

- Divider with "or" label
- `SecondaryButton` — "Create New Runner" — opens `RunnerInputForm` in a bottom sheet (via `sheet()` utility) with `showBibField: true` and bib pre-validation enforcing a unique, non-duplicate bib

**On resolution:** Progress increments, transitions to next conflict.

---

## 5. Unknown Bib Conflict Card

**When shown:** Second group — standalone unknown bibs.

**Card body:**

- `SectionHeaderWidget` — title "Unknown Bib", subtitle "Bib #421 isn't in the database"
- Entered bib number displayed prominently (large text)
- Finish position and finish time

**Same two-section layout as Section 4:**

### Option A — Assign to existing runner

- `SectionHeaderWidget` (compact) — "Nearby unassigned runners"
- `ListView` of `StandardListItem` rows (bib, name, proximity delta)
- Sorted by numeric proximity to the entered bib

### Option B — Create new runner

- Divider with "or" label
- `SecondaryButton` — "Create New Runner" — opens `RunnerInputForm` in a bottom sheet via `sheet()`, with `showBibField: true`

**On resolution:** Progress increments, transitions to next conflict.

---

## 6. Create New Runner Sheet

**Triggered by:** "Create New Runner" button in Sections 4 or 5.

**Implementation:** Reuses `RunnerInputForm` inside the existing `sheet()` utility from `sheet_utils.dart`.

**Configuration:**

- `useSheetLayout: true`
- `showBibField: true`
- For post-duplicate entry: bib field has extra validation — cannot match the conflicting duplicate bib (must be a new unique number)
- `submitButtonText`: "Add Runner"

**On confirm:**

- Runner is permanently saved to the team database
- Sheet closes
- Conflict is resolved; progress increments

---

## 7. Race Context Panel (shared component)

**Appears on:** All conflict cards (Sections 3, 4, 5).

**Implementation:** Collapsible section at the bottom of each `GlassCard`, using an `ExpansionTile` or equivalent animated expand/collapse.

**Collapsed state — label "Surrounding finishers":**

- Two `StandardListItem` rows:
  - Runner ahead: finish position (leading), name (title), bib + finish time (subtitle)
  - Runner behind: same layout
- If no runner exists ahead/behind, row shows "—"

**Expanded state ("See more"):**

- Expands to show ~5 finishers each side, or the full list
- Same `StandardListItem` row layout
- `AsyncContentSwitcher` wraps the list in case data is still loading
- Read-only — no tappable actions on any row

---

## 8. Completion Screen

**When shown:** After all conflicts are resolved, before results are committed.

**Layout:**

- `EmptyStateWidget`-style layout (success variant) — icon, title "All conflicts resolved"
- `GlassCard` summary block showing:
  - Duplicates resolved count
  - Runners assigned count
  - New runners created count
- `FullWidthButton` (primary) — "Confirm & Submit Results"
- `SecondaryButton` — "Review resolutions" (navigates back through resolved cards in read-only mode)
