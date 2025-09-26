# Race Timer App – Documentation

Last reviewed: 2025-08-11

This repository contains a multi-role Flutter app for timing cross-country and track races. The app supports three roles that can run on different devices and exchange data wirelessly:

- Coach: orchestrates races, manages participants, merges results
- Bib Recorder: captures bib-number order at the finish chute
- Race Timer: captures finish times and resolves timing conflicts

This docs folder is the home for user guides, developer guides, and architectural reference for the codebase in `lib/`.

## Table of Contents

- Overview and highlights
- Getting started for development
- Architecture and data model
- Connectivity and protocol
- Features and UI
- Development, testing, and release
- Operations and reference
- ADRs and contributing

See the numbered structure below for direct links.

## Highlights (what’s in the app)

- Flutter app targeting iOS, Android, macOS, Windows, Linux, and Web
- State management via `provider` and local `ChangeNotifier` controllers
- Local data in SQLite (`lib/core/utils/database_helper.dart`); normalized schema with migrations
- Remote data in Postgres/Supabase (`db/remote_schema.sql`), with an offline‑first `SyncService` that uses UUIDs, updated_at cursors, and is_dirty flags (LWW conflict resolution)
- Wireless device connectivity via Nearby Connections (`lib/core/services/device_connection_service.dart`) using strategy P2P_STAR and a custom data `Protocol` (`lib/core/utils/data_protocol.dart`) with ACK/DATA/FIN framing and checksums
- Event bus for decoupled cross-module communication (`lib/core/services/event_bus.dart`)
- Service locator for lightweight DI (`lib/core/services/service_locator.dart`)
- Feature modules: `assistant/` (timing, bib recorder), `coach/` (race setup, flows, results), plus `shared/` models and `core/` components/services

## Quick start (development)

1) Install Flutter and platform SDKs.
2) Create a `.env` at repo root with keys like `APP_NAME` and optional `SENTRY_DSN`.
3) Run: `flutter pub get`
4) Launch: `flutter run` (or via your IDE)

See the Documentation Plan for the full docs outline and priorities.

## Read next

- 01 Getting Started: [01-getting-started.md](01-getting-started.md)
- 02 Architecture: [02-architecture/overview.md](02-architecture/overview.md)
- 03 Data: [03-data/overview.md](03-data/overview.md), [03-data/local-schema.md](03-data/local-schema.md), [03-data/remote-schema.md](03-data/remote-schema.md), [03-data/sync-service.md](03-data/sync-service.md)
- 04 Connectivity: [04-connectivity/protocol.md](04-connectivity/protocol.md)
- 05 Features: [05-features/timing.md](05-features/timing.md), [05-features/bib-recorder.md](05-features/bib-recorder.md), [05-features/coach-flows.md](05-features/coach-flows.md)
- 06 UI: [06-ui/theme.md](06-ui/theme.md)
- 07 Dev (Testing): [07-dev/testing.md](07-dev/testing.md)
- 08 Dev (Build & Release): [08-dev/build-and-release.md](08-dev/build-and-release.md)
- 09 Ops (Environment): [09-ops/environment.md](09-ops/environment.md)
- 10 Reference: [10-reference/event-bus.md](10-reference/event-bus.md), [10-reference/api/remote-api-client.md](10-reference/api/remote-api-client.md)
- ADRs: [adr/README.md](adr/README.md), [adr/template.md](adr/template.md)
- Documentation plan (for maintainers): [documentation-plan.md](documentation-plan.md)
