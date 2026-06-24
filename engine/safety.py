#!/usr/bin/env python3
"""
Safety guards for CKAQuest.
Prevents destructive operations outside the ckaquest namespace.
"""

import re
from rich.console import Console
from rich.panel import Panel

console = Console()

NAMESPACE = "ckaquest"

# Patterns that are always blocked
BLOCKED_PATTERNS = [
    (
        r"kubectl\s+delete\s+namespace\s+(kube-system|kube-public|kube-node-lease|default)",
        "Cannot delete critical system namespaces.",
    ),
    (
        r"kubectl\s+delete\s+(node|nodes)\b",
        "Cannot delete cluster nodes.",
    ),
    (
        r"kubectl\s+.*--all-namespaces.*delete",
        "Cross-namespace delete operations are blocked.",
    ),
    (
        r"k3s\s+server\s+--disable",
        "Cannot disable k3s server components.",
    ),
    (
        r"systemctl\s+(stop|disable)\s+k3s",
        "Cannot stop the k3s service during a mission.",
    ),
]

# Patterns that require confirmation
WARN_PATTERNS = [
    (
        r"kubectl\s+delete\s+namespace\s+(?!ckaquest)\w+",
        "You are about to delete a namespace outside ckaquest.",
    ),
    (
        r"kubectl\s+delete\s+.*--all\b",
        "You are about to delete all resources of a type.",
    ),
    (
        r"kubectl\s+taint\s+nodes\s+--all",
        "Tainting all nodes will affect the entire cluster.",
    ),
]


def check_command(cmd: str) -> tuple[bool, str]:
    """
    Returns (allowed: bool, message: str).
    If allowed=False, the command should be blocked.
    """
    for pattern, msg in BLOCKED_PATTERNS:
        if re.search(pattern, cmd, re.IGNORECASE):
            console.print(Panel(
                f"[bold red]BLOCKED[/bold red]\n\n{msg}\n\n"
                f"[dim]Command: {cmd}[/dim]",
                title="[red]Safety Guard[/red]",
                border_style="red",
            ))
            return False, msg

    for pattern, msg in WARN_PATTERNS:
        if re.search(pattern, cmd, re.IGNORECASE):
            console.print(Panel(
                f"[bold yellow]WARNING[/bold yellow]\n\n{msg}",
                title="[yellow]Safety Guard[/yellow]",
                border_style="yellow",
            ))
            confirm = input("  Proceed? (yes/no): ").strip().lower()
            if confirm != "yes":
                return False, "Operation cancelled."

    return True, ""
