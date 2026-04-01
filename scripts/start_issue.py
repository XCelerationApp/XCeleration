#!/usr/bin/env python3
"""
Start working on a Linear issue.
Creates a git worktree branched from dev and opens it in Cursor.

Usage:
  python3 scripts/start_issue.py 123             # no simulator
  python3 scripts/start_issue.py 123 --simulator # create & boot a dedicated simulator
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time


def get_repo_root() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print("Error: must be run from inside the git repository")
        sys.exit(1)
    return result.stdout.strip()


def get_main_worktree_root() -> str:
    """Return the main (first) worktree path, regardless of where the script is run from."""
    result = subprocess.run(
        ["git", "worktree", "list", "--porcelain"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return get_repo_root()
    first_line = result.stdout.splitlines()[0]  # "worktree /path/to/main"
    return first_line.split(" ", 1)[1].strip()


def branch_exists(repo_root: str, branch: str) -> bool:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", branch],
        capture_output=True, cwd=repo_root,
    )
    return result.returncode == 0


def get_latest_ios_runtime() -> str:
    """Return the identifier of the latest available iOS runtime."""
    result = subprocess.run(
        ["xcrun", "simctl", "list", "runtimes", "--json"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print("Warning: could not list simulators runtimes — xcrun simctl unavailable")
        return ""
    data = json.loads(result.stdout)
    ios_runtimes = [
        r for r in data.get("runtimes", [])
        if r.get("name", "").startswith("iOS") and r.get("isAvailable", False)
    ]
    if not ios_runtimes:
        return ""
    ios_runtimes.sort(key=lambda r: r.get("version", "0"))
    return ios_runtimes[-1]["identifier"]


def create_simulator(issue_id: str, worktree_path: str) -> None:
    """Create and boot a dedicated simulator for the worktree, persist its UDID."""
    runtime = get_latest_ios_runtime()
    if not runtime:
        print("Warning: no iOS runtime found — skipping simulator creation")
        return

    print(f"Creating simulator '{issue_id}'...")
    result = subprocess.run(
        ["xcrun", "simctl", "create", issue_id, "iPhone 16", runtime],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"Warning: could not create simulator\n{result.stderr.strip()}")
        return

    udid = result.stdout.strip()
    udid_path = os.path.join(worktree_path, ".simulator_udid")
    with open(udid_path, "w") as f:
        f.write(udid + "\n")
    print(f"Simulator UDID   : {udid}")

    print("Booting simulator...")
    boot = subprocess.run(
        ["xcrun", "simctl", "boot", udid],
        capture_output=True, text=True,
    )
    if boot.returncode != 0 and "already booted" not in boot.stderr.lower():
        print(f"Warning: could not boot simulator\n{boot.stderr.strip()}")
    else:
        print("Simulator booted.")


def main():
    parser = argparse.ArgumentParser(
        description="Start working on a Linear issue.",
        usage="python3 scripts/start_issue.py 123 [--simulator]",
    )
    parser.add_argument("issue_number", help="Linear issue number (digits only, e.g. 123)")
    parser.add_argument(
        "--simulator", "-s",
        action="store_true",
        default=False,
        help="Create and boot a dedicated iPhone simulator for this worktree",
    )
    args = parser.parse_args()

    if not args.issue_number.isdigit():
        print(f"Error: '{args.issue_number}' is not a valid issue number — pass only the number, e.g. 123")
        sys.exit(1)

    issue_id = f"XCE-{args.issue_number}"

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

    # Remove settings.local.json if present — it can disable MCPs and override settings.json
    settings_local = os.path.join(worktree_path, ".claude", "settings.local.json")
    if os.path.exists(settings_local):
        os.remove(settings_local)

    # Copy .env from main repo (gitignored, required for flutter test)
    env_src = os.path.join(get_main_worktree_root(), ".env")
    env_dst = os.path.join(worktree_path, ".env")
    if os.path.isfile(env_src) and not os.path.exists(env_dst):
        shutil.copy2(env_src, env_dst)

    # Write .linear-issue marker so /done can find the issue ID
    marker_path = os.path.join(worktree_path, ".linear-issue")
    with open(marker_path, "w") as f:
        f.write(issue_id + "\n")

    # Optionally create and boot a dedicated simulator for this worktree
    if args.simulator:
        create_simulator(issue_id, worktree_path)

    # Run flutter pub get in the new worktree
    subprocess.run(["flutter", "pub", "get"], cwd=worktree_path)

    print(f"Worktree : {worktree_path}")
    print(f"Branch   : {branch}")

    # Open in a new Cursor window
    cursor_bin = "/usr/local/bin/cursor"
    if os.path.isfile(cursor_bin):
        subprocess.Popen([cursor_bin, "-n", worktree_path])
        print("Opened in Cursor.")
    else:
        print("\nCould not find Cursor at /usr/local/bin/cursor. Open manually:")
        print(f"  cursor -n {worktree_path}")


if __name__ == "__main__":
    main()
