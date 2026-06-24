#!/usr/bin/env python3
"""Player name selection for CKAQuest."""

import random
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt

console = Console()

ADJECTIVES = [
    "Swift", "Clever", "Ninja", "Quantum", "Async", "Binary", "Kernel",
    "Kubectl", "Atomic", "Resilient", "Scalable", "Reliable", "Certified",
]

NOUNS = [
    "Admin", "Operator", "Engineer", "Deployer", "Debugger", "Architect",
    "SRE", "DevOps", "Cluster", "Scheduler", "Controller",
]


def generate_random_name() -> str:
    adj = random.choice(ADJECTIVES)
    noun = random.choice(NOUNS)
    suffix = random.choice(["", str(random.randint(1, 99)), "42", "CKA"])
    return f"{adj}{noun}{suffix}"


def get_player_name() -> str:
    console.print(Panel(
        "[bold cyan]Welcome to CKAQuest![/bold cyan]\n\n"
        "What should we call you?",
        title="[bold]Player Setup[/bold]",
        border_style="cyan",
    ))

    console.print("  [1] Enter your name")
    console.print("  [2] Generate a random name")
    console.print("  [3] Use default: CKA Candidate")
    console.print()

    choice = Prompt.ask("Choose", choices=["1", "2", "3"], default="3")

    if choice == "1":
        name = Prompt.ask("Your name").strip()
        return name if name else "CKA Candidate"
    elif choice == "2":
        name = generate_random_name()
        console.print(f"\n  Generated: [bold yellow]{name}[/bold yellow]")
        return name
    else:
        return "CKA Candidate"
