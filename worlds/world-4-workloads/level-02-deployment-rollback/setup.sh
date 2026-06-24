#!/usr/bin/env bash
# Create revision 1 with a working image before broken.yaml applies revision 2
set -euo pipefail
NS="ckaquest"

# Deploy the initial working revision
kubectl apply -n "$NS" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ${NS}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF

# Wait for it to be ready so rollout history records revision 1
kubectl rollout status deployment/api -n "$NS" --timeout=60s || true
