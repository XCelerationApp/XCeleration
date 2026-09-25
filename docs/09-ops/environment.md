# 09 — Environment (.env)

Last reviewed: 2026-09-21

There are two env files. Both are gitignored.

| File | Read by | Bundled into the app? |
| --- | --- | --- |
| `.env` (repo root) | the app (`flutter_dotenv`), `ios/scripts/inject_env.sh`, fastlane | **Yes** — listed under `flutter: assets:` in `pubspec.yaml` |
| `ios/fastlane/.env` | fastlane only | No |

Anything in the root `.env` can be read by anyone who unzips the app, so it must
only hold values that are safe to be public. `scripts/check_bundled_env.sh`
enforces this in CI and before deploys.

## Root `.env` (app config — public-safe only)

- `APP_NAME`: Shown in UI
- `SENTRY_DSN`, `SENTRY_TRACES_SAMPLE_RATE`: Optional crash reporting; if empty, Sentry disabled
- `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`: Optional remote sync; if empty, remote disabled
- `GOOGLE_IOS_OAUTH_CLIENT_ID`, `GOOGLE_IOS_OAUTH_REVERSED_CLIENT_ID`, `GOOGLE_WEB_OAUTH_CLIENT_ID`, `GOOGLE_APP_ID`, `GOOGLE_WEB_API_KEY`, `GOOGLE_PICKER_URL`, `WEB_ACCESS_TOKEN_API_ENDPOINT`: Google sign-in / Drive picker (restrict `GOOGLE_WEB_API_KEY` in Google Cloud)
- `BUNDLE_ID`, `TEAM_ID`: Used by `inject_env.sh` and fastlane

## `ios/fastlane/.env` (build secrets — never bundled)

- `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_BASE64`
- `MATCH_PASSWORD`, `FASTLANE_MATCH_REPO_URL`

`scripts/check_bundled_env.sh` fails if any `APP_STORE_CONNECT_*`, `MATCH_*`,
`FASTLANE_*` or `SUPABASE_SERVICE_ROLE_KEY` key appears in the root `.env`.

## CI secrets

- `DOTENV`: contents of the root `.env` (no build secrets)
- `FASTLANE_DOTENV`: contents of `ios/fastlane/.env` (deploy workflow only)

## Behavior when missing

- Remote sync skipped (logs: "Remote not configured; skipping sync.")
- App functions locally with SQLite

## References

- `lib/main.dart`, `lib/core/services/remote_api_client.dart`
- `ios/fastlane/Fastfile`, `ios/scripts/inject_env.sh`
- `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`
