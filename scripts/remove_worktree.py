#!/usr/bin/env python3
"""
Remove the git worktree for a Linear issue and delete the local branch.

Leaves the remote branch and PR open for review and merging.
Linear issue status is not changed — use /done for that.

Usage: python3 scripts/remove_worktree.py 123
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


def run(args: list[str], cwd: str = None, capture: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=capture, text=True, cwd=cwd)


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/remove_worktree.py 123")
        sys.exit(1)

    arg = sys.argv[1]

    if not arg.isdigit():
        print(f"Error: '{arg}' is not a valid issue number — pass only the number, e.g. 123")
        sys.exit(1)

    issue_id = f"XCE-{arg}"
    repo_root = get_repo_root()
    worktree_path = os.path.join(os.path.dirname(repo_root), issue_id)
    branch = issue_id

    # Verify worktree exists
    if not os.path.isdir(worktree_path):
        print(f"Error: no worktree found at {worktree_path}")
        sys.exit(1)

    print(f"Removing worktree for {issue_id}...")

    # Safety check: uncommitted changes
    status = run(["git", "status", "--porcelain"], cwd=worktree_path)
    if status.stdout.strip():
        print("Error: uncommitted changes in the worktree — commit or stash before finishing:")
        print(status.stdout.rstrip())
        sys.exit(1)

    # Safety check: unpushed commits
    unpushed = run(
        ["git", "log", f"origin/{branch}..HEAD", "--oneline"],
        cwd=worktree_path,
    )
    if unpushed.returncode != 0:
        # Remote branch may not exist yet
        print(f"Warning: could not check remote for {branch} — make sure everything is pushed")
    elif unpushed.stdout.strip():
        print("Error: unpushed commits in the worktree — push before finishing:")
        print(unpushed.stdout.rstrip())
        sys.exit(1)

    # Delete the paired simulator (if present)
    udid_file = os.path.join(worktree_path, ".simulator_udid")
    if os.path.isfile(udid_file):
        with open(udid_file) as f:
            udid = f.read().strip()
        if udid:
            print(f"Deleting simulator : {udid}")
            sim_result = run(["xcrun", "simctl", "delete", udid])
            if sim_result.returncode != 0:
                print(f"Warning: could not delete simulator {udid}\n{sim_result.stderr.rstrip()}")
            else:
                print("Simulator deleted.")

    # Remove the worktree
    result = run(["git", "worktree", "remove", worktree_path, "--force"], cwd=repo_root)
    if result.returncode != 0:
        print(f"Error: failed to remove worktree\n{result.stderr.rstrip()}")
        sys.exit(1)
    print(f"Removed worktree : {worktree_path}")

    # Delete the local branch
    result = run(["git", "branch", "-D", branch], cwd=repo_root)
    if result.returncode != 0:
        print(f"Warning: could not delete local branch '{branch}'\n{result.stderr.rstrip()}")
    else:
        print(f"Deleted branch   : {branch}")

    print(f"\nDone. Remote branch and PR for {issue_id} are still open for review.")


if __name__ == "__main__":
    main()
