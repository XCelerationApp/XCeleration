# 03 — Sync Service

Last reviewed: 2025-08-11

Source: `lib/core/services/sync_service.dart`

## Responsibilities

- Ensure local rows have `uuid`
- Push rows where `is_dirty=1` (strip `is_dirty` on payload)
- Pull by `updated_at` cursor and apply LWW (Last-Write-Wins)
- Persist cursors in `sync_state`

## Cursors

- Keys: `cursor.runners`, `cursor.teams`, `cursor.races`, `cursor.race_results`
- Stored in local table `sync_state(key TEXT PRIMARY KEY, value TEXT)`

## Push

- Select `is_dirty=1` rows per table
- Upsert by `uuid` remotely; then clear flags for sent `uuid`s

## Pull

- Query remote where `updated_at > cursor`, ordered by `updated_at`
- For each row: insert if missing else compare timestamps and update if remote is newer
- Track `newCursor` as max `updated_at` seen; then persist

## Error handling and backoff

- Initialization checks for remote configuration; skips gracefully if not configured
- Logs via `Logger.d/e`; caller can catch and retry with backoff

## Open questions / future work

- Soft-deletes with `deleted_at` replication
- Batch sizes and pagination beyond 1000
- Conflict audits/metrics
