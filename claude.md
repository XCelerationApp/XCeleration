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
- **Using any Supabase MCP tool:** Read `skills/SUPABASE_MCP_SKILL.md`
- **Committing changes, creating branches, or opening/updating a PR:** Read `skills/GIT_WORKFLOW_SKILL.md` — **MUST be read before any git action, no exceptions**

## Always

- Run `flutter analyze` after every meaningful change
- Run `python3 scripts/test_runner.py  <path/to/specific_test.dart>` for the test files related to your changes
- Run the full `python3 scripts/test_runner.py` before committing to catch regressions
- One concern per commit
- Ask the user before opening a new PR or renaming the curerent branch

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

After regenerating mocks, redundant per-line ignores are fixed **automatically** by a PostToolUse hook (`scripts/fix_mock_ignores.py`). No manual cleanup required.

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

## Disk Cleanup

If a build fails with `No space left on device`, run the disk cleanup script:

```sh
bash scripts/disk_cleanup.sh
```

It scans common dev caches (Xcode, simulators, CocoaPods, Flutter, npm, etc.), shows sizes sorted largest-first, and prints ready-to-run cleanup commands with safety labels.

## Issue Worktree Workflow

Start an issue: `python3 scripts/start_issue.py 123` (from the main repo).
Finish an issue: `/done` (from Claude Code inside the worktree) — marks the Linear issue Done.
Clean up worktree: `python3 scripts/remove_worktree.py 123` (from the main repo) — removes the local worktree and branch. Leaves the remote branch and PR open.

See `skills/GIT_WORKFLOW_SKILL.md` and `skills/LINEAR_WORKFLOW_SKILL.md` for full details.

---

## Web Search

When the user asks you to look something up, research a library, find documentation, or says anything like "go search…" / "find out how to…" / "look up…", use the `/search` skill immediately. Do not attempt to answer from memory alone for questions about external APIs, packages, or anything that may have changed — search first.

## When Unsure — Ask First

If a request is unclear, ambiguous, or could be interpreted multiple ways, always ask (using the AskUserQuestion tool) for clarification before starting. Do not make assumptions and proceed. A short question upfront is better than work that needs to be redone.

## Tool Failures and Missing Tools

**If a task-execution tool stops working** (e.g. `test_runner.py` fails, `start_issue.py` errors, a Linear/GitHub MCP tool returns unexpected errors): stop immediately, flag the exact error to the user, and do not attempt Bash workarounds. Broken tooling should be fixed at the source, not routed around.

**If a task-execution tool is missing** — you notice mid-task that a tool would make the workflow meaningfully better (e.g. no script to do X, no shortcut for a repeated operation), ask the user with AskUserQuestion whether to create a Linear issue to build it. Examples of things that warrant this prompt:

- Running a repeated multi-step operation with no dedicated script
- A workflow step that requires manual Bash commands where a script clearly belongs
- An MCP capability gap that causes repeated friction

Do not file the issue yourself — ask first. One question, one prompt.
