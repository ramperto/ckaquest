#!/bin/bash

CURRENT=$(kubectl config current-context 2>/dev/null)

if kubectl get nodes &>/dev/null 2>&1; then
  echo "✅ kubectl works! Current context: $CURRENT"
  exit 0
fi

echo "❌ kubectl cannot connect. Current context: ${CURRENT:-none}"
echo ""
echo "💡 List contexts: kubectl config get-contexts"
echo "   Switch context: kubectl config use-context <name>"
exit 1
