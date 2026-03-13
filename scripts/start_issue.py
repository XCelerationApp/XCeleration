#!/usr/bin/env python3
"""
Start working on a Linear issue.
Creates a git worktree branched from dev and opens it in Cursor.

Usage: python3 scripts/start_issue.py 123
"""
import os
import subprocess
import sys


def get_repo_root() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print("Error: must be run from inside the git repository")
        sys.exit(1)
    return result.stdout.strip()


def branch_exists(repo_root: str, branch: str) -> bool:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", branch],
        capture_output=True, cwd=repo_root,
    )
    return result.returncode == 0


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/start_issue.py 123")
        sys.exit(1)

    arg = sys.argv[1]

    if not arg.isdigit():
        print(f"Error: '{arg}' is not a valid issue number — pass only the number, e.g. 123")
        sys.exit(1)

    issue_id = f"XCE-{arg}"

    repo_root = get_repo_root()
    worktree_path = os.path.join(os.path.dirname(repo_root), f"{issue_id}")
    branch = issue_id

    if os.path.exists(worktree_path):
        print(f"Worktree already exists at {worktree_path}")
    else:
        print(f"Creating worktree for {issue_id}...")
        if branch_exists(repo_root, branch):
            # Branch exists — attach worktree to it
            result = subprocess.run(
                ["git", "worktree", "add", worktree_path, branch],
                cwd=repo_root,
            )
        else:
            # New branch from dev
            result = subprocess.run(
                ["git", "worktree", "add", "-b", branch, worktree_path, "dev"],
                cwd=repo_root,
            )

        if result.returncode != 0:
            print("Error: failed to create worktree")
            sys.exit(1)

    # Write .linear-issue marker so /done can find the issue ID
    marker_path = os.path.join(worktree_path, ".linear-issue")
    with open(marker_path, "w") as f:
        f.write(issue_id + "\n")

    print(f"Worktree : {worktree_path}")
    print(f"Branch   : {branch}")

    # Open in Cursor
    result = subprocess.run(["cursor", worktree_path], capture_output=True)
    if result.returncode != 0:
        print("\nCursor not found in PATH. Open manually:")
        print(f"  cursor {worktree_path}")
    else:
        print("Opened in Cursor.")


if __name__ == "__main__":
    main()
