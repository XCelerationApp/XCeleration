# 03 — Local Schema (SQLite)

Last reviewed: 2025-08-11

Schema defined in `lib/core/utils/database_helper.dart` (version 10).

## Tables

- `runners(runner_id PK autoinc, uuid UNIQUE, name NOT NULL, grade, bib_number UNIQUE NOT NULL, timestamps, deleted_at, is_dirty)`
- `teams(team_id PK autoinc, uuid UNIQUE, name UNIQUE NOT NULL, abbreviation<=3, color, timestamps, deleted_at, is_dirty)`
- `team_rosters(team_id, runner_id, joined_date, PK(team_id, runner_id))`
- `race_team_participation(race_id, team_id, team_color_override, PK(race_id, team_id))`
- `race_participants(race_id, runner_id, team_id, PK(race_id, runner_id))`
- `races(race_id PK autoinc, uuid UNIQUE, name NOT NULL, race_date, location, distance, distance_unit, flow_state, timestamps, deleted_at, is_dirty)`
- `race_results(result_id PK autoinc, uuid UNIQUE, race_id, runner_id, place, finish_time, timestamps, deleted_at, is_dirty, UNIQUE(race_id, runner_id), UNIQUE(race_id, place))`
- `sync_state(key PK, value)`

## Indexes (selected)

- `idx_runners_name_grade`, `idx_runners_bib`
- `idx_teams_name`, `idx_teams_abbreviation`
- `idx_race_results_race`, `idx_race_results_place`

## Migrations

- Version 10 adds `uuid`, `deleted_at`, `is_dirty` to primary tables and creates `sync_state`.
- Use `onUpgrade` to backfill columns where absent; keep migrations idempotent.

## Write semantics

- Create/Update paths set `is_dirty=1` and refresh `updated_at`.
- Deletes use `DELETE` currently; future soft-deletes may use `deleted_at`.
