#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
SCHEDULABLE=$(kubectl get node "$NODE" \
  -o jsonpath='{.spec.unschedulable}' 2>/dev/null)

# The node must be schedulable (uncordoned) for the mission to be complete
if [[ "$SCHEDULABLE" == "true" ]]; then
  echo "❌ Node '$NODE' is still cordoned (unschedulable)."
  echo "   After maintenance, you must uncordon the node."
  echo ""
  echo "💡 kubectl uncordon $NODE"
  exit 1
fi

# Check node is Ready
STATUS=$(kubectl get node "$NODE" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

if [[ "$STATUS" == "True" ]]; then
  echo "✅ Node '$NODE' is Ready and schedulable — drain + uncordon complete!"
  echo "   A proper drain/uncordon cycle was performed."
  exit 0
fi

echo "❌ Node '$NODE' is not Ready. Status: ${STATUS:-unknown}"
exit 1
