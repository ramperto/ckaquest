#!/usr/bin/env python3
"""
CKAQuest level reset tool.
Usage:
  python3 engine/reset.py level-01-crashloop
  python3 engine/reset.py all
"""

import subprocess
import sys
from pathlib import Path

NAMESPACE = "ckaquest"
BASE_DIR = Path(__file__).parent.parent
WORLDS_DIR = BASE_DIR / "worlds"
PROGRESS_FILE = BASE_DIR / "progress.json"


def kubectl(*args) -> subprocess.CompletedProcess:
    return subprocess.run(["kubectl", *args], capture_output=True, text=True)


def find_level(level_name: str) -> Path | None:
    for world_dir in sorted(WORLDS_DIR.iterdir()):
        if not world_dir.is_dir():
            continue
        for level_dir in world_dir.iterdir():
            if level_dir.is_dir() and level_dir.name == level_name:
                return level_dir
    return None


def reset_level(level_path: Path):
    print(f"Resetting {level_path.name}...")
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true")
    kubectl("create", "namespace", NAMESPACE)

    broken = level_path / "broken.yaml"
    setup = level_path / "setup.sh"

    if setup.exists():
        subprocess.run(["bash", str(setup)], check=False)

    if broken.exists():
        subprocess.run(["kubectl", "apply", "-f", str(broken), "-n", NAMESPACE], check=False)

    print(f"  Done — {level_path.name} redeployed.")


def reset_all():
    print("Resetting entire game...")
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true")
    kubectl("create", "namespace", NAMESPACE)

    if PROGRESS_FILE.exists():
        PROGRESS_FILE.unlink()

    print("  All progress cleared.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 engine/reset.py <level-name|all>")
        sys.exit(1)

    target = sys.argv[1]

    if target == "all":
        reset_all()
    else:
        level = find_level(target)
        if level is None:
            print(f"Level '{target}' not found.")
            sys.exit(1)
        reset_level(level)
