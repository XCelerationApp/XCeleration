#!/usr/bin/env python3
"""
Flutter test runner with concise output.
Usage:
  python3 scripts/test_runner.py                           # run all tests
  python3 scripts/test_runner.py path/to/test.dart        # single file
  python3 scripts/test_runner.py test/unit/               # whole folder
  python3 scripts/test_runner.py file1.dart test/unit/    # multiple targets
"""

import json
import subprocess
import sys
from collections import defaultdict

import shutil
FLUTTER = shutil.which("flutter") or "/Users/finiandonnelley/Programming_project/flutter/bin/flutter"


def run_tests(paths=None):
    cmd = [FLUTTER, "test", "--reporter=json"]
    if paths:
        cmd.extend(paths)

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    tests = {}          # id -> name
    errors = defaultdict(list)   # id -> error lines
    passed = 0
    failed = 0
    skipped = 0

    for raw in proc.stdout:
        raw = raw.strip()
        if not raw:
            continue
        try:
            event = json.loads(raw)
        except json.JSONDecodeError:
            continue

        t = event.get("type")

        if t == "testStart":
            test = event["test"]
            tests[test["id"]] = test["name"]

        elif t == "error":
            tid = event["testID"]
            error_msg = event.get("error", "")
            stack = event.get("stackTrace", "")
            # Keep first 3 lines of stack trace
            stack_lines = [l for l in stack.splitlines() if l.strip()][:3]
            errors[tid].append(error_msg)
            if stack_lines:
                errors[tid].extend(stack_lines)

        elif t == "testDone":
            tid = event["testID"]
            result = event.get("result", "")
            hidden = event.get("hidden", False)
            if hidden:
                continue
            if result == "success":
                passed += 1
            elif result == "error" or result == "failure":
                failed += 1
            elif result == "skipped":
                skipped += 1

        elif t == "done":
            break

    proc.wait()

    total = passed + failed + skipped
    print(f"\n{'='*60}")
    print(f"Results: {passed} passed, {failed} failed, {skipped} skipped  (total: {total})")
    print(f"{'='*60}")

    if errors:
        print(f"\nFailed tests ({len(errors)}):\n")
        for tid, err_lines in errors.items():
            name = tests.get(tid, f"<test #{tid}>")
            print(f"  FAIL: {name}")
            for line in err_lines:
                # Trim long lines
                line = line.strip()
                if len(line) > 120:
                    line = line[:117] + "..."
                print(f"        {line}")
            print()

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    run_tests(sys.argv[1:] or None)
