#!/usr/bin/env python3
"""Remove per-line // ignore: comments that duplicate // ignore_for_file: headers.

Scans every *.mocks.dart file under test/ and removes any trailing
  // ignore: <diagnostic>
that is already suppressed by a file-level
  // ignore_for_file: <diagnostic>
header — these cause a `duplicate_ignore` lint error in CI.

Usage:
  python3 scripts/fix_mock_ignores.py          # fix all test/**/*.mocks.dart
"""

import re
import sys
from pathlib import Path


def fix_file(path: Path) -> bool:
    content = path.read_text()
    lines = content.splitlines(keepends=True)

    # Collect all diagnostics already suppressed at file level.
    file_ignores: set[str] = set()
    for line in lines:
        m = re.match(r'\s*//\s*ignore_for_file:\s*(.+)', line)
        if m:
            for diag in m.group(1).split(','):
                file_ignores.add(diag.strip())

    if not file_ignores:
        return False

    new_lines: list[str] = []
    changed = False
    for line in lines:
        # Match an optional code prefix followed by a trailing // ignore: comment.
        m = re.match(r'^(.*?)\s*//\s*ignore:\s*(.+?)(\s*)$', line.rstrip('\n'))
        if m:
            code_part = m.group(1)
            ignore_diags = [d.strip() for d in m.group(2).split(',')]
            remaining = [d for d in ignore_diags if d not in file_ignores]
            if len(remaining) < len(ignore_diags):
                changed = True
                newline_char = '\n' if line.endswith('\n') else ''
                if remaining:
                    new_lines.append(
                        f'{code_part} // ignore: {", ".join(remaining)}{newline_char}'
                    )
                elif code_part.strip():
                    # Keep the code, strip only the now-redundant comment.
                    new_lines.append(code_part.rstrip() + newline_char)
                # else: the entire line was only the ignore comment — drop it.
                continue
        new_lines.append(line)

    if changed:
        path.write_text(''.join(new_lines))
        print(f'  fixed: {path}')

    return changed


def main() -> None:
    root = Path('.')
    mock_files = sorted(root.glob('test/**/*.mocks.dart'))

    if not mock_files:
        sys.exit(0)

    fixed = sum(1 for f in mock_files if fix_file(f))
    if fixed:
        print(f'fix_mock_ignores: fixed {fixed} file(s).')
    sys.exit(0)


if __name__ == '__main__':
    main()
