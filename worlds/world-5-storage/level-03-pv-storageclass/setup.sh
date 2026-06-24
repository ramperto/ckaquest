#!/usr/bin/env bash
kubectl delete pv app-pv --ignore-not-found=true --wait=false 2>/dev/null || true
kubectl delete sc manual --ignore-not-found=true 2>/dev/null || true
kubectl delete sc standard --ignore-not-found=true 2>/dev/null || true
sleep 1
