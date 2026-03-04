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

- Run `dart format .` and `flutter analyze` after every meaningful change
- Run `flutter test <path/to/specific_test.dart>` for the test files related to your changes
- Run the full `flutter test` before committing to catch regressions
- One concern per commit

## Working Style

When a task requires manual verification (e.g. "does this look right on device?",
"which of these approaches do you prefer?"), always stop and ask before proceeding.
Never assume or pick arbitrarily. Use the AskUserQuestion tool to present options clearly.

## Running Flutter Commands

The `dart` and `flutter` binaries are not on PATH in non-interactive shells. Always use full paths:

```sh
/Users/finiandonnelley/Programming_project/flutter/bin/dart format .
/Users/finiandonnelley/Programming_project/flutter/bin/flutter analyze
/Users/finiandonnelley/Programming_project/flutter/bin/flutter test
```

When adding or changing mocks (e.g. after `@GenerateMocks` changes):

```sh
/Users/finiandonnelley/Programming_project/flutter/bin/dart run build_runner build --delete-conflicting-outputs
```

## Reading Test Output

`flutter test` produces 50KB+ of output — the Bash tool truncates it before failures are visible.
Always tee to a file, then use the Read/Grep tools on the file:

```sh
# Full suite
source ~/.zshrc && flutter test 2>&1 | tee /tmp/flutter_test_output.txt; echo "EXIT_CODE: $?"

# Single file
source ~/.zshrc && flutter test path/to/test.dart 2>&1 | tee /tmp/flutter_test_output.txt; echo "EXIT_CODE: $?"
```

- Use the **Read tool** on `/tmp/flutter_test_output.txt` with `offset`/`limit` to paginate
- Use **Grep** on `/tmp/flutter_test_output.txt` to find `FAILED`, `Error`, `Exception`
- Do NOT pipe to `tail` or `grep` in Bash — those also hit the size limit

## When Unsure — Ask First

If a request is unclear, ambiguous, or could be interpreted multiple ways, always ask (using the AskUserQuestion tool) for clarification before starting. Do not make assumptions and proceed. A short question upfront is better than work that needs to be redone.
