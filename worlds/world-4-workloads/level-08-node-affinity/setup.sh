#!/usr/bin/env bash
# Label the node with zone=us-west before broken.yaml is applied
set -euo pipefail

NODE=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name | head -1)
if [[ -z "$NODE" ]]; then
  echo "ERROR: could not determine node name"
  exit 1
fi
kubectl label node "$NODE" zone=us-west --overwrite
echo "Node '$NODE' labelled: zone=us-west"
