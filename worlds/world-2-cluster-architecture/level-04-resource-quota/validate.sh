#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

READY=$(kubectl get deployment webapp -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
DESIRED=$(kubectl get deployment webapp -n "$NS" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null)

if [[ "$READY" == "3" && "$DESIRED" == "3" ]]; then
  echo "✅ Deployment 'webapp' has 3/3 ready replicas! Quota resolved."
  exit 0
fi

QUOTA_PODS=$(kubectl get resourcequota tight-quota -n "$NS" \
  -o jsonpath='{.spec.hard.pods}' 2>/dev/null)
USED_PODS=$(kubectl get resourcequota tight-quota -n "$NS" \
  -o jsonpath='{.status.used.pods}' 2>/dev/null)

echo "❌ Deployment 'webapp' only has ${READY:-0}/${DESIRED:-3} ready replicas."
echo "   ResourceQuota: pods used=${USED_PODS:-?}/${QUOTA_PODS:-?}"
echo ""
echo "💡 Check: kubectl describe resourcequota tight-quota -n $NS"
echo "   Increase the 'pods' limit in the quota to at least 3."
exit 1
