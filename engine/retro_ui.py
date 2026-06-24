#!/usr/bin/env python3
"""Retro UI components for CKAQuest."""

import time
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.align import Align
from rich import box

console = Console()

LOGO = """\
  ██████ ██   ██  █████   ██████  ██    ██ ███████ ███████ ████████
 ██      ██  ██  ██   ██ ██    ██ ██    ██ ██      ██         ██
 ██      █████   ███████ ██    ██ ██    ██ █████   ███████    ██
 ██      ██  ██  ██   ██ ██ ▄▄ ██ ██    ██ ██           ██    ██
  ██████ ██   ██ ██   ██  ██████   ██████  ███████ ███████    ██
                               ▀▀
"""

WORLD_BANNERS = {
    "world-1-troubleshooting": "[bold red]World 1: Troubleshooting[/bold red]",
    "world-2-cluster-architecture": "[bold blue]World 2: Cluster Architecture[/bold blue]",
    "world-3-networking": "[bold green]World 3: Services & Networking[/bold green]",
    "world-4-workloads": "[bold yellow]World 4: Workloads & Scheduling[/bold yellow]",
    "world-5-storage": "[bold magenta]World 5: Storage[/bold magenta]",
}

DIFFICULTY_COLORS = {
    "beginner": "green",
    "intermediate": "yellow",
    "advanced": "red",
    "expert": "bold red",
}


def show_welcome(player_name: str, total_xp: int, completed: int, total_levels: int = 80):
    console.clear()
    console.print(f"[bold cyan]{LOGO}[/bold cyan]")
    console.print(Panel(
        f"[bold]CKA Exam Preparation Platform[/bold]\n\n"
        f"  Player  : [cyan]{player_name}[/cyan]\n"
        f"  Total XP: [yellow]{total_xp:,}[/yellow]\n"
        f"  Progress: [green]{completed}/{total_levels}[/green] levels completed",
        border_style="cyan",
        box=box.DOUBLE,
    ))


def show_level_start(level_name: str, mission: dict):
    diff = mission.get("difficulty", "beginner")
    diff_color = DIFFICULTY_COLORS.get(diff, "white")
    xp = mission.get("xp", 100)

    console.print(Panel(
        f"[bold]{mission.get('name', level_name)}[/bold]\n\n"
        f"  Difficulty : [{diff_color}]{diff.upper()}[/{diff_color}]\n"
        f"  XP Reward  : [yellow]{xp} XP[/yellow]\n"
        f"  Est. Time  : {mission.get('expected_time', '?')}\n\n"
        f"[dim]{mission.get('description', '')}[/dim]",
        title=f"[bold cyan]MISSION BRIEFING[/bold cyan]",
        border_style="cyan",
    ))


def show_victory(level_name: str, xp_earned: int, total_xp: int):
    console.print(Panel(
        f"[bold green]LEVEL COMPLETE![/bold green]\n\n"
        f"  +{xp_earned} XP earned\n"
        f"  Total XP: [yellow]{total_xp:,}[/yellow]",
        title="[bold green]★ SUCCESS ★[/bold green]",
        border_style="green",
        box=box.DOUBLE,
    ))


def show_failure(message: str):
    console.print(Panel(
        f"[yellow]{message}[/yellow]\n\n"
        f"[dim]Use 'hints' for help, or 'check' to monitor resources.[/dim]",
        title="[yellow]Not Yet...[/yellow]",
        border_style="yellow",
    ))


def show_command_menu():
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


def show_world_complete(world_name: str, xp: int):
    banner = WORLD_BANNERS.get(world_name, f"[bold]{world_name}[/bold]")
    console.print(Panel(
        f"{banner} [bold green]COMPLETE![/bold green]\n\n"
        f"  World XP: [yellow]{xp:,}[/yellow]\n\n"
        f"[bold]Excellent work! CKA exam domain mastered.[/bold]",
        title="[bold yellow]★ WORLD COMPLETE ★[/bold yellow]",
        border_style="yellow",
        box=box.DOUBLE,
    ))
