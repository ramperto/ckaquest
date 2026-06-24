#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Create a StorageClass that does NOT allow expansion
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: no-expand-sc
provisioner: rancher.io/local-path
reclaimPolicy: Delete
allowVolumeExpansion: false
EOF

# Create a PVC already bound
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: $NS
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: no-expand-sc
  resources:
    requests:
      storage: 500Mi
EOF
