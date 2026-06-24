#!/bin/bash
# Place a broken static pod manifest in the kubelet's static pod directory

STATIC_POD_DIR="/etc/kubernetes/manifests"
sudo mkdir -p "$STATIC_POD_DIR"

# Write a broken static pod manifest (invalid image + wrong restart policy)
sudo tee "$STATIC_POD_DIR/infra-monitor.yaml" > /dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: infra-monitor
  namespace: kube-system
  labels:
    tier: control-plane
    component: infra-monitor
spec:
  restartPolicy: Never    # BUG: static pods must use Always
  hostNetwork: true
  containers:
    - name: monitor
      image: busybox:1.36
      command: ["shh", "-c", "sleep 3600"]  # BUG: typo "shh" not "sh"
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
EOF

echo "Broken static pod manifest placed at $STATIC_POD_DIR/infra-monitor.yaml"
echo "kubelet will try to start it — check its status in a few seconds."
echo "  kubectl get pods -n kube-system | grep infra-monitor"
