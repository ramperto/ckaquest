#!/usr/bin/env python3
"""
CKAQuest - CKA Exam Preparation Game
Main game engine.
"""

import json
import os
import random
import subprocess
import sys
import termios
import tty
from pathlib import Path

import yaml
from rich import box
from rich.columns import Columns
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from rich.table import Table
from rich.text import Text

try:
    from retro_ui import (
        show_welcome,
        show_level_start,
        show_victory,
        show_failure,
        show_command_menu,
        show_world_complete,
        DIFFICULTY_COLORS,
    )
    RETRO_UI = True
except ImportError:
    RETRO_UI = False
    DIFFICULTY_COLORS = {
        "beginner": "green",
        "intermediate": "yellow",
        "advanced": "red",
        "expert": "bold red",
    }

console = Console()

NAMESPACE = "ckaquest"
BASE_DIR = Path(__file__).parent.parent
WORLDS_DIR = BASE_DIR / "worlds"
PROGRESS_FILE = BASE_DIR / "progress.json"

CKA_DOMAINS = {
    "world-1-troubleshooting": {
        "name": "Troubleshooting",
        "weight": "30%",
        "color": "red",
        "icon": "🔧",
    },
    "world-2-cluster-architecture": {
        "name": "Cluster Architecture & Config",
        "weight": "25%",
        "color": "blue",
        "icon": "⚙️",
    },
    "world-3-networking": {
        "name": "Services & Networking",
        "weight": "20%",
        "color": "green",
        "icon": "🌐",
    },
    "world-4-workloads": {
        "name": "Workloads & Scheduling",
        "weight": "15%",
        "color": "yellow",
        "icon": "📦",
    },
    "world-5-storage": {
        "name": "Storage",
        "weight": "10%",
        "color": "magenta",
        "icon": "💾",
    },
}



def count_all_levels() -> int:
    """Dynamically count all levels across all worlds."""
    return sum(
        1 for w in WORLDS_DIR.iterdir() if w.is_dir()
        for l in w.iterdir() if l.is_dir() and (l / "mission.yaml").exists()
    )


# ── Helpers ──────────────────────────────────────────────────────────────────

def kubectl(*args, capture: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["kubectl", *args],
        capture_output=capture,
        text=True,
    )


def natural_sort_key(p: Path) -> list:
    import re
    parts = re.split(r"(\d+)", p.name)
    return [int(x) if x.isdigit() else x.lower() for x in parts]


def level_key(level_path: Path) -> str:
    """Unique string key for a level: 'world-1-troubleshooting/level-01-crashloop'"""
    return f"{level_path.parent.name}/{level_path.name}"


def load_mission(level_path: Path) -> dict:
    mission_file = level_path / "mission.yaml"
    if mission_file.exists():
        with open(mission_file) as f:
            return yaml.safe_load(f) or {}
    return {}


def getch() -> str:
    """Read a single character without Enter."""
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        return sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


# ── Progress ──────────────────────────────────────────────────────────────────

def load_progress() -> dict:
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {
        "player_name": None,
        "total_xp": 0,
        "completed_levels": [],
        "validate_attempts": {},
    }


def save_progress(progress: dict):
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2)


# ── Deployment ────────────────────────────────────────────────────────────────

def restore_kubeconfig():
    """Restore ~/.kube/config from k3s canonical copy before each level setup."""
    k3s_cfg = Path("/etc/rancher/k3s/k3s.yaml")
    kube_cfg = Path.home() / ".kube" / "config"
    if k3s_cfg.exists():
        import shutil
        kube_cfg.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(k3s_cfg), str(kube_cfg))
        kube_cfg.chmod(0o600)



def deploy_mission(level_path: Path) -> bool:
    """Tear down and redeploy the broken mission state."""
    console.print("[dim]Preparing mission environment...[/dim]")

    # Restore kubeconfig before each level so previous kubeconfig-breaking
    # levels don't cascade failures into subsequent levels.
    restore_kubeconfig()

    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true", "--wait=true")
    kubectl("create", "namespace", NAMESPACE)

    setup_sh = level_path / "setup.sh"
    if setup_sh.exists():
        result = subprocess.run(["bash", str(setup_sh)], capture_output=True, text=True)
        if result.returncode != 0:
            console.print(f"[yellow]setup.sh warning: {result.stderr.strip()}[/yellow]")

    broken_yaml = level_path / "broken.yaml"
    if broken_yaml.exists() and any(l.strip() and not l.strip().startswith("#") for l in broken_yaml.read_text().splitlines()):
        result = kubectl("apply", "-f", str(broken_yaml), "-n", NAMESPACE)
        if result.returncode != 0:
            console.print(f"[red]Failed to deploy broken state:[/red]\n{result.stderr.strip()}")
            return False

    console.print("[dim]Mission environment ready.[/dim]\n")
    return True


# ── Resource Monitor ──────────────────────────────────────────────────────────

def get_resource_status() -> Table:
    table = Table(
        title=f"Namespace: {NAMESPACE}",
        box=box.ROUNDED,
        show_header=True,
        header_style="bold cyan",
    )
    table.add_column("Kind", style="cyan", width=14)
    table.add_column("Name", width=28)
    table.add_column("Status / Ready", width=18)
    table.add_column("Age", width=8)

    resources = [
        ("pods", "Pod"),
        ("deployments", "Deployment"),
        ("services", "Service"),
        ("configmaps", "ConfigMap"),
        ("secrets", "Secret"),
        ("persistentvolumeclaims", "PVC"),
    ]

    for resource, kind in resources:
        result = kubectl(
            "get", resource, "-n", NAMESPACE,
            "--no-headers", "-o",
            "custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,STATUS:.status.phase,AGE:.metadata.creationTimestamp",
        )
        if result.returncode != 0 or not result.stdout.strip():
            continue
        for line in result.stdout.strip().splitlines():
            parts = line.split()
            if not parts:
                continue
            name = parts[0] if len(parts) > 0 else "-"
            status = parts[1] if len(parts) > 1 else "-"
            age = parts[-1] if len(parts) > 2 else "-"
            # Skip default configmaps/secrets
            if name in ("kube-root-ca.crt", "default-token"):
                continue
            table.add_row(kind, name, status, age)

    return table


def monitor_resources():
    import threading, time
    stop_event = threading.Event()

    def wait_key():
        getch()
        stop_event.set()

    t = threading.Thread(target=wait_key, daemon=True)
    t.start()

    while not stop_event.is_set():
        # clear + reprint works reliably over SSH (no ANSI cursor-up needed)
        console.clear()
        console.print("[dim]Live status (press any key to stop)...[/dim]\n")
        console.print(get_resource_status())
        time.sleep(2)

    # final clean snapshot after stopping
    console.clear()
    console.print(get_resource_status())


# ── Hints ─────────────────────────────────────────────────────────────────────

def show_hints(level_path: Path, attempts: int):
    hints_unlocked = min(attempts, 3)
    if hints_unlocked == 0:
        console.print(Panel(
            "[yellow]Hints unlock after your first validation attempt.[/yellow]\n"
            "Try [cyan]validate[/cyan] first!",
            border_style="yellow",
        ))
        return

    for i in range(1, hints_unlocked + 1):
        hint_file = level_path / f"hint-{i}.txt"
        if hint_file.exists():
            text = hint_file.read_text().strip()
            console.print(Panel(
                text,
                title=f"[bold yellow]Hint {i}/{hints_unlocked}[/bold yellow]",
                border_style="yellow",
            ))

    remaining = 3 - hints_unlocked
    if remaining > 0:
        console.print(f"[dim]  {remaining} more hint(s) unlock after more attempts.[/dim]")


# ── Solution ──────────────────────────────────────────────────────────────────

def show_solution(level_path: Path):
    solution_file = level_path / "solution.yaml"
    if solution_file.exists():
        content = solution_file.read_text().strip()
        console.print(Panel(
            f"[dim]{content}[/dim]",
            title="[bold]Reference Solution[/bold]",
            border_style="dim",
        ))
    else:
        console.print("[yellow]No solution file for this level.[/yellow]")


# ── Validation ────────────────────────────────────────────────────────────────

def validate_mission(level_path: Path) -> tuple[bool, str]:
    validate_sh = level_path / "validate.sh"
    if not validate_sh.exists():
        return False, "No validate.sh found for this level."

    result = subprocess.run(
        ["bash", str(validate_sh)],
        capture_output=True,
        text=True,
        env={**os.environ, "NAMESPACE": NAMESPACE},
    )

    output = result.stdout.strip() or result.stderr.strip()
    return result.returncode == 0, output


# ── Debrief ───────────────────────────────────────────────────────────────────

def show_debrief(level_path: Path):
    debrief_file = level_path / "debrief.md"
    if not debrief_file.exists():
        return

    content = debrief_file.read_text().strip()
    lines = content.splitlines()
    page_size = 30
    pages = [lines[i:i + page_size] for i in range(0, len(lines), page_size)]
    total = len(pages)

    for idx, page in enumerate(pages, 1):
        console.print(Panel(
            "\n".join(page),
            title=f"[bold cyan]Post-Mission Debrief ({idx}/{total})[/bold cyan]",
            border_style="cyan",
        ))
        if idx < total:
            console.print("[dim]Press Enter for next page, q to skip...[/dim]")
            ch = getch()
            if ch.lower() == "q":
                break


# ── Level Play ────────────────────────────────────────────────────────────────

def play_level(level_path: Path, progress: dict) -> bool:
    """
    Returns True if completed, False if skipped/quit.
    Mutates progress in-place.
    """
    key = level_key(level_path)
    mission = load_mission(level_path)

    already_done = key in progress["completed_levels"]

    if RETRO_UI:
        show_level_start(level_path.name, mission)
    else:
        diff = mission.get("difficulty", "beginner")
        diff_color = DIFFICULTY_COLORS.get(diff, "white")
        console.print(Panel(
            f"[bold]{mission.get('name', level_path.name)}[/bold]\n\n"
            f"  Difficulty : [{diff_color}]{diff.upper()}[/{diff_color}]\n"
            f"  XP Reward  : [yellow]{mission.get('xp', 100)} XP[/yellow]\n"
            f"  Est. Time  : {mission.get('expected_time', '?')}\n\n"
            f"{mission.get('description', '')}",
            title="[bold cyan]MISSION BRIEFING[/bold cyan]",
            border_style="cyan",
        ))

    objective = mission.get("objective", "")
    if objective:
        console.print(Panel(
            f"[bold green]Objective:[/bold green] {objective}",
            border_style="green",
        ))

    concepts = mission.get("concepts", [])
    if concepts:
        console.print(f"[dim]CKA Concepts: {', '.join(concepts)}[/dim]\n")

    if already_done:
        console.print("[green]You already completed this level![/green] Replaying for practice.\n")

    if not deploy_mission(level_path):
        return False

    if RETRO_UI:
        show_command_menu()
    else:
        console.print(Panel(
            "  [cyan]check[/cyan]     — Monitor live resource status\n"
            "  [cyan]hints[/cyan]     — Show progressive hints\n"
            "  [cyan]solution[/cyan]  — View reference solution\n"
            "  [cyan]validate[/cyan]  — Test your fix\n"
            "  [cyan]reset[/cyan]     — Redeploy broken state from scratch\n"
            "  [cyan]skip[/cyan]      — Skip level (no XP)\n"
            "  [cyan]quit[/cyan]      — Save and exit",
            title="[bold]Commands[/bold]",
            border_style="dim",
        ))

    attempts = progress["validate_attempts"].get(key, 0)

    while True:
        try:
            cmd = Prompt.ask("\n[bold cyan]>[/bold cyan]").strip().lower()
        except (EOFError, KeyboardInterrupt):
            console.print("\n[yellow]Use 'quit' to exit.[/yellow]")
            continue

        if cmd == "check":
            monitor_resources()

        elif cmd in ("hint", "hints"):
            show_hints(level_path, attempts)

        elif cmd == "solution":
            show_solution(level_path)

        elif cmd == "validate":
            console.print("[dim]Running validation...[/dim]")
            passed, output = validate_mission(level_path)
            attempts += 1
            progress["validate_attempts"][key] = attempts

            if passed:
                xp = mission.get("xp", 100)
                if key not in progress["completed_levels"]:
                    progress["completed_levels"].append(key)
                    progress["total_xp"] = progress.get("total_xp", 0) + xp
                    save_progress(progress)
                    if RETRO_UI:
                        show_victory(level_path.name, xp, progress["total_xp"])
                    else:
                        console.print(Panel(
                            f"[bold green]LEVEL COMPLETE![/bold green]\n"
                            f"  +{xp} XP\n"
                            f"  Total XP: [yellow]{progress['total_xp']:,}[/yellow]",
                            title="[bold green]SUCCESS[/bold green]",
                            border_style="green",
                        ))
                else:
                    console.print(Panel(
                        "[green]Correct! (already completed — no duplicate XP)[/green]",
                        border_style="green",
                    ))
                    save_progress(progress)

                console.print(f"\n[dim]{output}[/dim]")
                show_debrief(level_path)
                return True

            else:
                msg = output or "Validation failed. Keep trying!"
                if RETRO_UI:
                    show_failure(msg)
                else:
                    console.print(Panel(
                        f"[yellow]{msg}[/yellow]\n\n"
                        f"[dim]Attempt {attempts} — hints unlock after each failure.[/dim]",
                        title="[yellow]Not Yet[/yellow]",
                        border_style="yellow",
                    ))
                save_progress(progress)

        elif cmd == "reset":
            console.print("[dim]Resetting mission environment...[/dim]")
            if deploy_mission(level_path):
                console.print("[green]Mission reset — broken state redeployed.[/green]")
                attempts = 0
                progress["validate_attempts"][key] = 0
                save_progress(progress)
            else:
                console.print("[red]Reset failed — check cluster connectivity.[/red]")

        elif cmd == "skip":
            console.print("[yellow]Level skipped. No XP awarded.[/yellow]")
            save_progress(progress)
            return False

        elif cmd == "quit":
            save_progress(progress)
            console.print("\n[yellow]Progress saved. Good luck on your CKA![/yellow]\n")
            sys.exit(0)

        elif cmd in ("help", "?", "h"):
            if RETRO_UI:
                show_command_menu()
            else:
                console.print("Commands: check, hints, solution, validate, reset, skip, quit")

        elif cmd == "":
            pass

        else:
            console.print(f"[dim]Unknown command '{cmd}'. Type 'help' for options.[/dim]")


# ── World Play ────────────────────────────────────────────────────────────────

def play_world(world_path: Path, progress: dict):
    world_name = world_path.name
    domain = CKA_DOMAINS.get(world_name, {"name": world_name, "color": "white"})

    levels = sorted(
        [d for d in world_path.iterdir() if d.is_dir()],
        key=natural_sort_key,
    )

    console.print(Panel(
        f"[bold]Domain: {domain.get('icon', '')} {domain['name']}[/bold]\n"
        f"CKA Exam Weight: [bold]{domain.get('weight', '?')}[/bold]\n\n"
        f"Levels: {len(levels)}",
        title=f"[bold {domain.get('color', 'white')}]{world_name.upper()}[/bold {domain.get('color', 'white')}]",
        border_style=domain.get("color", "white"),
    ))

    world_xp_start = progress.get("total_xp", 0)

    for level_path in levels:
        if not (level_path / "mission.yaml").exists():
            continue

        key = level_key(level_path)
        status = "[green]✓[/green]" if key in progress["completed_levels"] else "[dim]○[/dim]"
        mission = load_mission(level_path)
        console.print(f"  {status} {level_path.name}  [dim]{mission.get('name', '')}[/dim]")

    console.print()
    choice = Prompt.ask(
        "Play sequentially from beginning, or pick a level?",
        choices=["start", "pick", "back"],
        default="start",
    )

    if choice == "back":
        return

    if choice == "start":
        # Find first incomplete level
        start_idx = 0
        for i, level_path in enumerate(levels):
            if level_key(level_path) not in progress["completed_levels"]:
                start_idx = i
                break
        play_levels = levels[start_idx:]
    else:
        # Pick a specific level
        names = [l.name for l in levels]
        for i, name in enumerate(names, 1):
            console.print(f"  [{i}] {name}")
        pick = Prompt.ask("Level number")
        try:
            idx = int(pick) - 1
            play_levels = levels[idx:]
        except (ValueError, IndexError):
            console.print("[red]Invalid choice.[/red]")
            return

    for level_path in play_levels:
        if not (level_path / "mission.yaml").exists():
            continue
        play_level(level_path, progress)

    world_xp_earned = progress.get("total_xp", 0) - world_xp_start
    if world_xp_earned > 0 and RETRO_UI:
        show_world_complete(world_name, world_xp_earned)


# ── Progress Display ──────────────────────────────────────────────────────────

def show_progress_screen(progress: dict):
    completed = set(progress.get("completed_levels", []))
    total_xp = progress.get("total_xp", 0)

    table = Table(
        title="Your CKA Progress",
        box=box.ROUNDED,
        show_header=True,
        header_style="bold cyan",
    )
    table.add_column("Domain", style="bold")
    table.add_column("Levels", justify="center")
    table.add_column("Done", justify="center")
    table.add_column("Weight", justify="center")
    table.add_column("Status")

    worlds = sorted([d for d in WORLDS_DIR.iterdir() if d.is_dir()], key=natural_sort_key)

    for world_path in worlds:
        domain = CKA_DOMAINS.get(world_path.name, {"name": world_path.name, "color": "white", "weight": "?"})
        levels = [d for d in world_path.iterdir() if d.is_dir() and (d / "mission.yaml").exists()]
        total = len(levels)
        done = sum(1 for l in levels if level_key(l) in completed)
        pct = (done / total * 100) if total > 0 else 0
        bar = "█" * int(pct / 10) + "░" * (10 - int(pct / 10))
        color = domain.get("color", "white")
        table.add_row(
            f"[{color}]{domain['name']}[/{color}]",
            str(total),
            str(done),
            domain.get("weight", "?"),
            f"[cyan]{bar}[/cyan] {pct:.0f}%",
        )

    console.print(table)
    console.print(f"\n  Total XP: [yellow bold]{total_xp:,}[/yellow bold]")
    console.print(f"  Levels completed: [green]{len(completed)}/{count_all_levels()}[/green]\n")


# ── Main Menu ─────────────────────────────────────────────────────────────────

def main_menu(progress: dict) -> str:
    player = progress.get("player_name", "CKA Candidate")
    total_xp = progress.get("total_xp", 0)
    completed = len(progress.get("completed_levels", []))

    if RETRO_UI:
        show_welcome(player, total_xp, completed, count_all_levels())
    else:
        console.print(Panel(
            f"[bold]CKAQuest — CKA Exam Preparation[/bold]\n\n"
            f"  Player  : [cyan]{player}[/cyan]\n"
            f"  Total XP: [yellow]{total_xp:,}[/yellow]\n"
            f"  Progress: [green]{completed}/{count_all_levels()} levels[/green]",
            border_style="cyan",
        ))

    console.print("  [1] Play")
    console.print("  [2] View Progress")
    console.print("  [3] Quit")
    console.print()

    choice = Prompt.ask("Select", choices=["1", "2", "3"], default="1")
    return {"1": "play", "2": "progress", "3": "quit"}[choice]


def select_world(progress: dict):
    worlds = sorted([d for d in WORLDS_DIR.iterdir() if d.is_dir()], key=natural_sort_key)

    if not worlds:
        console.print("[red]No worlds found in worlds/ directory.[/red]")
        return

    console.print(Panel("[bold]Select a CKA Domain[/bold]", border_style="cyan"))

    for i, world_path in enumerate(worlds, 1):
        domain = CKA_DOMAINS.get(world_path.name, {"name": world_path.name, "weight": "?", "icon": ""})
        levels = [d for d in world_path.iterdir() if d.is_dir() and (d / "mission.yaml").exists()]
        done = sum(1 for l in levels if level_key(l) in set(progress.get("completed_levels", [])))
        color = domain.get("color", "white")
        console.print(
            f"  [{i}] [{color}]{domain.get('icon', '')} {domain['name']}[/{color}]"
            f"  [dim]({domain.get('weight', '?')} of exam | {done}/{len(levels)} done)[/dim]"
        )

    console.print(f"  [b] Back")
    console.print()

    choices = [str(i) for i in range(1, len(worlds) + 1)] + ["b"]
    choice = Prompt.ask("Select world", choices=choices, default="1")

    if choice == "b":
        return

    world_path = worlds[int(choice) - 1]
    play_world(world_path, progress)


# ── Player Setup ─────────────────────────────────────────────────────────────

_ADJECTIVES = ["Swift", "Clever", "Ninja", "Quantum", "Async", "Binary", "Kernel",
               "Kubectl", "Atomic", "Resilient", "Scalable", "Reliable", "Certified"]
_NOUNS = ["Admin", "Operator", "Engineer", "Deployer", "Debugger", "Architect",
          "SRE", "DevOps", "Cluster", "Scheduler", "Controller"]


def get_player_name() -> str:
    console.print(Panel(
        "[bold cyan]Welcome to CKAQuest![/bold cyan]\n\nWhat should we call you?",
        title="[bold]Player Setup[/bold]",
        border_style="cyan",
    ))
    console.print("  [1] Enter your name")
    console.print("  [2] Generate a random name")
    console.print("  [3] Use default: CKA Candidate\n")

    choice = Prompt.ask("Choose", choices=["1", "2", "3"], default="3")
    if choice == "1":
        name = Prompt.ask("Your name").strip()
        return name or "CKA Candidate"
    if choice == "2":
        suffix = random.choice(["", str(random.randint(1, 99)), "42", "CKA"])
        name = f"{random.choice(_ADJECTIVES)}{random.choice(_NOUNS)}{suffix}"
        console.print(f"\n  Generated: [bold yellow]{name}[/bold yellow]")
        return name
    return "CKA Candidate"


# ── Entry Point ───────────────────────────────────────────────────────────────

def main():
    progress = load_progress()

    # First run: get player name
    if progress.get("player_name") is None:
        progress["player_name"] = get_player_name()
        save_progress(progress)

    while True:
        choice = main_menu(progress)

        if choice == "play":
            select_world(progress)
        elif choice == "progress":
            show_progress_screen(progress)
        elif choice == "quit":
            console.print("\n[yellow]Progress saved. Keep grinding for that CKA![/yellow]\n")
            break


if __name__ == "__main__":
    main()
