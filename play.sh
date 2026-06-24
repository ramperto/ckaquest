#!/bin/bash
# CKAQuest launcher

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d "venv" ]; then
  echo "Virtual environment not found. Run ./install.sh first."
  exit 1
fi

if ! kubectl get nodes &>/dev/null 2>&1; then
  echo "ERROR: Cannot reach Kubernetes cluster."
  echo "  Make sure k3s is running: sudo systemctl status k3s"
  echo "  If stopped: sudo systemctl start k3s"
  exit 1
fi

export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"
exec venv/bin/python3 engine/engine.py "$@"
