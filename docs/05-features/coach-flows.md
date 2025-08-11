# 05 — Feature: Coach Flows & Race Management

Last reviewed: 2025-08-11

## Code

- Controllers: `coach/races_screen/controller/races_controller.dart`, `coach/race_screen/controller/race_screen_controller.dart`
- Flows: `coach/flows/**`
- Merge conflicts UI: `coach/merge_conflicts/**`

## Flow

1. Create or select a race
2. Manage participants (teams, runners)
3. Receive bibs/times and resolve conflicts
4. Review and export results

## Events

- Uses EventBus events like `race.flowState.changed` to notify UI components
