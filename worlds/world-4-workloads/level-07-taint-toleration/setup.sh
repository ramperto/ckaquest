#!/usr/bin/env bash
# Taint the node before broken.yaml is applied (so the pod starts Pending)
set -euo pipefail

NODE=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name | head -1)
if [[ -z "$NODE" ]]; then
  echo "ERROR: could not determine node name"
  exit 1
fi
kubectl taint node "$NODE" gpu=present:NoSchedule --overwrite
echo "Node '$NODE' tainted: gpu=present:NoSchedule"
