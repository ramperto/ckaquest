#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check that platform-viewer can now list pods (via aggregation from logs-reader)
CAN_PODS=$(kubectl auth can-i list pods \
  --as=system:serviceaccount:${NS}:platform-sa 2>/dev/null)

# Check that platform-viewer can list events (via events-reader — was already working)
CAN_EVENTS=$(kubectl auth can-i list events \
  --as=system:serviceaccount:${NS}:platform-sa 2>/dev/null)

if [[ "$CAN_PODS" == "yes" && "$CAN_EVENTS" == "yes" ]]; then
  echo "✅ platform-viewer now has permissions from both aggregated ClusterRoles!"
  echo "   Can list pods: yes (from logs-reader)"
  echo "   Can list events: yes (from events-reader)"
  exit 0
fi

echo "❌ platform-viewer is missing permissions."
echo "   Can list pods: ${CAN_PODS:-no}"
echo "   Can list events: ${CAN_EVENTS:-no}"
echo ""
echo "💡 Check if logs-reader has the aggregation label:"
echo "   kubectl get clusterrole logs-reader -o jsonpath='{.metadata.labels}'"
echo ""
echo "   Add it: kubectl label clusterrole logs-reader \\"
echo "     rbac.ckaquest.io/aggregate-to-platform-viewer=true"
exit 1
