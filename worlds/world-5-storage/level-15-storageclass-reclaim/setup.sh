#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Create a StorageClass with Delete reclaim policy
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: delete-sc
provisioner: rancher.io/local-path
reclaimPolicy: Delete
EOF
