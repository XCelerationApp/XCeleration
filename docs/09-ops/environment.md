# 09 — Environment (.env)

Last reviewed: 2025-08-11

## Keys

- `APP_NAME`: Shown in UI
- `SENTRY_DSN`: Optional crash reporting; if empty, Sentry disabled
- `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`: Optional remote sync; if empty, remote disabled

## Behavior when missing

- Remote sync skipped (logs: "Remote not configured; skipping sync.")
- App functions locally with SQLite

## References

- Used in `lib/main.dart`, `lib/core/services/remote_api_client.dart`
