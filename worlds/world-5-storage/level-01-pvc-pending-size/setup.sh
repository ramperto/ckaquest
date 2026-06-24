#!/usr/bin/env bash
# Clean up stale cluster-scoped resources from any previous run
kubectl delete pv db-pv --ignore-not-found=true --wait=false 2>/dev/null || true
kubectl delete sc manual --ignore-not-found=true 2>/dev/null || true
sleep 1
