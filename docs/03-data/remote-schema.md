# 03 — Remote Schema (Postgres/Supabase)

Last reviewed: 2025-08-11

SQL lives in [db/remote_schema.sql](../../db/remote_schema.sql). See also [db/schema_mapping.md](../../db/schema_mapping.md).

## Conventions

- `uuid` primary identity for sync; database-level `uuid_generate_v4()` defaults recommended.
- `updated_at` triggers on update; indices on `updated_at` and `uuid`.
- Unique constraints mirror local constraints (`runners.bib_number`, etc.).

## Tables (high level)

- `runners(uuid PK, name, grade, bib_number UNIQUE, timestamps, deleted_at)`
- `teams(uuid PK, name UNIQUE, abbreviation, color, timestamps, deleted_at)`
- Bridge tables for rosters and participation mirroring local FKs
- `races(uuid PK, name, race_date, location, distance, unit, flow_state, timestamps, deleted_at)`
- `race_results(uuid PK, race_uuid FK, runner_uuid FK, place, finish_time, timestamps, deleted_at, UNIQUE(race_uuid, runner_uuid), UNIQUE(race_uuid, place))`

## Indexes/Triggers

- `CREATE INDEX ... ON <table>(updated_at)` to accelerate cursor pulls.
- Trigger `updated_at = now()` on `INSERT/UPDATE`.
