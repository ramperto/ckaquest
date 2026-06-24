# CKAQuest

A terminal-based CKA exam preparation game. Work through hands-on Kubernetes troubleshooting scenarios in a real k3s cluster and earn XP for fixing broken deployments.

```
  ██████ ██   ██  █████   ██████  ██    ██ ███████ ███████ ████████
 ██      ██  ██  ██   ██ ██    ██ ██    ██ ██      ██         ██
 ██      █████   ███████ ██    ██ ██    ██ █████   ███████    ██
 ██      ██  ██  ██   ██ ██ ▄▄ ██ ██    ██ ██           ██    ██
  ██████ ██   ██ ██   ██  ██████   ██████  ███████ ███████    ██
```

## Requirements

- Ubuntu/Linux
- Python 3.9+
- `curl`, `jq` (auto-installed if missing)

`kubectl`, `k3s`, and `etcdctl` are installed automatically by the installer.

## Installation

```bash
git clone <repo>
cd ckaquest
./install.sh
```

The installer sets up k3s with embedded etcd, configures kubeconfig, creates the `ckaquest` namespace, and builds a Python virtualenv.

## Playing

```bash
./play.sh
```

If k3s isn't running: `sudo systemctl start k3s`

### In-game commands

| Command | Description |
|---|---|
| `check` | Live resource monitor for the `ckaquest` namespace |
| `hints` | Progressive hints (unlocks one per failed attempt, up to 3) |
| `solution` | View the reference solution |
| `validate` | Run the automated checker — earn XP on pass |
| `reset` | Redeploy the broken state from scratch |
| `skip` | Skip the level (no XP) |
| `quit` | Save and exit |

## Worlds

| World | CKA Domain | Exam Weight |
|---|---|---|
| World 1 | Troubleshooting | 30% |
| World 2 | Cluster Architecture & Config | 25% |
| World 3 | Services & Networking | 20% |
| World 4 | Workloads & Scheduling | 15% |
| World 5 | Storage | 10% |

## Cleanup

```bash
# Remove namespace, progress, and venv (keeps k3s/kubectl)
./cleanup.sh

# Full uninstall — removes k3s, kubectl, and etcdctl too
./cleanup.sh --full
```

## Adding levels

Create a directory under the appropriate world:

```
worlds/world-N-name/level-NN-slug/
├── mission.yaml    # name, description, objective, difficulty, xp, expected_time, concepts
├── broken.yaml     # manifests applied to create the broken state
├── setup.sh        # optional: imperative setup before broken.yaml
├── validate.sh     # exits 0 on success; receives NAMESPACE=ckaquest
├── solution.yaml   # reference solution shown on demand
├── hint-1.txt
├── hint-2.txt
├── hint-3.txt
└── debrief.md      # explanation shown after the player passes
```

Levels are auto-discovered and sorted by directory name — no registration needed.

## License

MIT
