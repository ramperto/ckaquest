#!/bin/bash
# Level 16 Setup: Apply NotReady taint to the node
NS="${NAMESPACE:-ckaquest}"

# Ensure namespace exists
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Get the node name (single-node k3s cluster)
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Apply the not-ready taint
kubectl taint nodes "$NODE" node.kubernetes.io/not-ready=true:NoSchedule --overwrite

echo "Setup complete: taint node.kubernetes.io/not-ready=true:NoSchedule applied to node $NODE"
