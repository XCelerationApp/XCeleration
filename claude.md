# XCeleration — Claude Reference

## GitHub Repository

- **Owner:** `XCelerationApp`
- **Repo:** `XCeleration`

## Stack

Flutter, Dart, ChangeNotifier + Provider, SQLite, Supabase.

## Skill Files — Read Before Acting

- **Refactoring any existing file:** Read `skills/REFACTORING_SKILL.md`
- **Adding or modifying a service, controller, or screen:** Read `skills/ERROR_HANDLING_SKILL.md`
- **Writing or modifying tests:** Read `skills/TESTING_SKILL.md`
- **Building or modifying any UI file (widgets, screens, components):** Read `skills/UI_STANDARD_SKILL.md`
- **Interacting with a Linear issue (creating, updating, closing):** Read `skills/LINEAR_WORKFLOW_SKILL.md`
- **Committing changes, creating branches, or opening/updating a PR:** Read `skills/GIT_WORKFLOW_SKILL.md`

## Always

- Run `flutter analyze` after every meaningful change
- Run `python3 scripts/test_runner.py  <path/to/specific_test.dart>` for the test files related to your changes
- Run the full `python3 scripts/test_runner.py` before committing to catch regressions
- One concern per commit

## Working Style

When a task requires manual verification (e.g. "does this look right on device?",
"which of these approaches do you prefer?"), always stop and ask before proceeding.
Never assume or pick arbitrarily. Use the AskUserQuestion tool to present options clearly.

## Running Flutter Commands

The `dart` and `flutter` binaries are not on PATH in non-interactive shells. Always use full paths:

```sh
/Users/finiandonnelley/Programming_project/flutter/bin/flutter analyze
```

When adding or changing mocks (e.g. after `@GenerateMocks` changes):

```sh
/Users/finiandonnelley/Programming_project/flutter/bin/dart run build_runner build --delete-conflicting-outputs
```

## Running Tests

Always use the custom test runner — it parses `flutter test --reporter=json` and prints a concise summary that fits in a single Bash tool read:

```sh
python3 scripts/test_runner.py                           # all tests
python3 scripts/test_runner.py path/to/test.dart        # single file
python3 scripts/test_runner.py test/unit/               # whole folder
python3 scripts/test_runner.py test/unit/ test/integration/  # multiple targets
python3 scripts/test_runner.py -v [targets...]          # verbose: full stack traces, no line truncation
```

Output: pass/fail/skip counts + test name and first few error lines for each failure. Exit code 1 if any fail.

Use `-v` when the default output truncates the error and more context is needed.

Do NOT use `flutter test` directly for reading results — its raw output exceeds the Bash tool's readable limit. Do NOT add `2>&1` to the runner command.

## When Unsure — Ask First

If a request is unclear, ambiguous, or could be interpreted multiple ways, always ask (using the AskUserQuestion tool) for clarification before starting. Do not make assumptions and proceed. A short question upfront is better than work that needs to be redone.
