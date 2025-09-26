# Remote vs Local Schema Mapping and Sync Notes

Overview

- Local storage: SQLite (`sqflite`) with normalized schema in `lib/core/utils/database_helper.dart` (version 9).
- Remote storage: Postgres/Supabase per `db/remote_schema.sql`.
- Goal: Logical parity across entities and constraints, with engine-specific types.

Entities (local → remote)

- runners: runner_id INTEGER → BIGINT; bib_number UNIQUE; timestamps; add `uuid`, `deleted_at` remote.
- teams: team_id INTEGER → BIGINT; `abbreviation` <= 3 chars; color stored as 32-bit ARGB integer; add `uuid`, `deleted_at` remote.
- team_rosters: composite PK (team_id, runner_id); CASCADE FKs; `joined_date` TEXT → timestamptz remote.
- races: race_id INTEGER → BIGINT; fields `name`, `race_date`, `location`, `distance`, `distance_unit`, `flow_state`; add `uuid`, `deleted_at` remote.
- race_team_participation: composite PK (race_id, team_id); `team_color_override` column name is canonical; ensure client uses that key.
- race_participants: composite PK (race_id, runner_id); team_id FK; CASCADE FKs.
- race_results: result_id INTEGER → BIGINT; `place`, `finish_time` (ms); uniqueness (race_id, runner_id) and (race_id, place); add `uuid`, `deleted_at` remote.

Type mappings

- TEXT (SQLite) ↔ text (Postgres)
- INTEGER (id) ↔ bigint (Postgres serial/bigserial)
- INTEGER (finish_time ms) ↔ integer (Postgres)
- TEXT ISO8601 timestamps ↔ timestamptz; remote uses server times. Client may still send ISO8601 in payloads.
- ARGB color int stored as INTEGER on both sides

Sync fields

- uuid: global identity across devices; present remote; recommended to add locally for robust sync.
- updated_at: LWW resolution; remote is authoritative; auto-updated by trigger.
- deleted_at: tombstone for soft deletes; present remote; recommended to add locally.
- is_dirty: local-only flag to mark unsynced changes; not present remote.

Ownership scoping for per-account data

- Remote tables include `owner_user_id uuid not null` (except purely relationship tables where it’s derived).
- RLS enforces `owner_user_id = auth.uid()`; participants/results inherit ownership via their race.
- Client push: set `owner_user_id` from the signed-in user.
- Client pull: always filter by `owner_user_id = currentUserId`.

Indexes and constraints

- Keep unique constraints aligned: runners.bib_number, race_results (race_id, runner_id), race_results (race_id, place).
- Maintain practical indexes for search/sorts (mirrored where useful).

Known naming consistency notes

- Use `team_color_override` consistently (local code fix needed in `TeamParticipant` to read/write this key).

Conflict handling guidance

- Default: last-writer-wins by `updated_at`.
- Structural conflicts (e.g., duplicate `(race_id, place)` from two devices): surface to conflict UI; perform guided resolution then upsert.
- Deletes: treat rows with `deleted_at` as removed; do not hard-delete immediately to allow propagation.

Operational notes

- Remote uses triggers to set `updated_at` server-side.
- Consider enabling RLS policies as needed for multi-user scenarios.
- For initial migration, backfill `uuid` for existing rows and set `updated_at` uniformly.
