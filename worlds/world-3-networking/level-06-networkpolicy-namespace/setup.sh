#!/bin/bash
# Create monitoring namespace and prometheus pod
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus
spec:
  containers:
    - name: prometheus
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF

echo "Namespace 'monitoring' and prometheus pod created."
