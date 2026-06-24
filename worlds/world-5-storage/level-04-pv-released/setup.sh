#!/usr/bin/env bash
# Create StorageClass, PV, bind with temp PVC, delete PVC → PV enters Released state
set -euo pipefail

# Clean up stale resources from any previous run
kubectl delete pv data-pv --ignore-not-found=true --wait=false 2>/dev/null || true
kubectl delete sc manual --ignore-not-found=true 2>/dev/null || true
sleep 1

# Create the StorageClass first (cluster-scoped, no-provisioner = static only)
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: manual
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
EOF

# Create the PV (cluster-scoped)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-pv
spec:
  capacity:
    storage: 4Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/ckaquest-data-pv
EOF

# Create a temporary PVC to bind the PV
kubectl apply -n ckaquest -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: temp-claim
  namespace: ckaquest
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 4Gi
EOF

# Wait for binding
for i in $(seq 1 20); do
  STATUS=$(kubectl get pvc temp-claim -n ckaquest -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [[ "$STATUS" == "Bound" ]]; then
    break
  fi
  sleep 2
done

# Delete the temporary PVC → PV transitions to Released
kubectl delete pvc temp-claim -n ckaquest --ignore-not-found=true
sleep 2
echo "PV data-pv should now be in Released state"
