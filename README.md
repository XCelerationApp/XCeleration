# XCeleration — Race Timing and Management

<img src="assets/icon/XCeleration_icon.png" alt="XCeleration Logo" width="120" />

Multi-role Flutter app for timing cross-country and track races. Roles: Coach, Bib Recorder, Race Timer. Supports iOS, Android, Web, and Desktop.

## Quick start

```bash
flutter pub get
flutter run
```

For full setup (supported versions, `.env`, iOS pods, multi-device test), see [docs/01-getting-started.md](docs/01-getting-started.md).

## Highlights

- Flutter multi-platform (iOS/Android/Web/Desktop)
- Offline-first: SQLite locally, optional Supabase remote sync
- Nearby Connections data transfer with custom DATA/ACK/FIN protocol
- EventBus and lightweight DI (Service Locator)

## Documentation

- Start here: [docs/README.md](docs/README.md)
- Architecture: [docs/02-architecture/overview.md](docs/02-architecture/overview.md)
- Data & Sync: [docs/03-data/overview.md](docs/03-data/overview.md)
- Connectivity: [docs/04-connectivity/protocol.md](docs/04-connectivity/protocol.md)
- Features: [docs/05-features/](docs/05-features/)
- Testing, Build & Release, Ops: [docs/07-dev/](docs/07-dev/), [docs/08-dev/](docs/08-dev/), [docs/09-ops/](docs/09-ops/)
- Reference: [docs/10-reference/](docs/10-reference/)

## Contributing

See [docs/contributing.md](docs/contributing.md) for workflow, commit conventions, and PR checklist.

## License

Proprietary. Unauthorized copying, distribution, or deployment is prohibited.

## Contact

Email `xceleration.app@gmail.com` for support or inquiries.
