#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check if monitor-sa can list pods using kubectl auth can-i
CAN_I=$(kubectl auth can-i list pods \
  --as=system:serviceaccount:${NS}:monitor-sa \
  -n "$NS" 2>/dev/null)

if [[ "$CAN_I" == "yes" ]]; then
  echo "✅ ServiceAccount 'monitor-sa' can now list pods in $NS!"
  exit 0
fi

# Check if RoleBinding exists
RB=$(kubectl get rolebinding -n "$NS" 2>/dev/null | grep monitor-sa)
if [[ -z "$RB" ]]; then
  echo "❌ No RoleBinding found for monitor-sa."
  echo ""
  echo "💡 A Role 'pod-reader' exists — you just need to bind it to monitor-sa."
  echo "   kubectl create rolebinding ... -n $NS"
else
  echo "❌ RoleBinding exists but permissions still not working."
  echo "   Check the roleRef and subjects in the binding."
fi

exit 1
