# Contributing

Last reviewed: 2025-08-11

## Code style

- Prefer clarity over cleverness; follow patterns in existing code
- Keep functions small with guard clauses; avoid deep nesting
- Use descriptive names; avoid abbreviations

## Workflow

- Create feature branches off main development branch
- Add tests for new behavior
- Update docs under `docs/` when public APIs or flows change

### Commit and branch conventions

- Branch: `feature/<short-topic>` or `fix/<short-topic>`
- Commits: Conventional Commits (e.g., `feat: add sync cursor for races`)

### Code quality

- Run `flutter analyze` and `flutter test` before PRs
- Format code with `dart format .`

## Testing

```bash
flutter test
dart run build_runner build --delete-conflicting-outputs
```

## PR checklist

- [ ] Lints pass and no analyzer warnings
- [ ] Tests added/updated and passing
- [ ] Docs added/updated
- [ ] Screenshots updated (if UI changes)
- [ ] Links verified and "Last reviewed" date set
