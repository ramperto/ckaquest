#!/bin/bash

PLAN_FILE="/tmp/upgrade-plan.sh"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "❌ File not found: $PLAN_FILE"
  echo "💡 Write your upgrade script to $PLAN_FILE"
  exit 1
fi

CONTENT=$(cat "$PLAN_FILE")
SCORE=0
ISSUES=()

# Check for key commands in order
check() {
  local pattern="$1"
  local desc="$2"
  if echo "$CONTENT" | grep -qE "$pattern"; then
    echo "  ✅ $desc"
    ((SCORE++))
  else
    echo "  ❌ $desc"
    ISSUES+=("$desc")
  fi
}

echo "Checking upgrade plan..."
echo ""
check "apt-mark unhold kubeadm"             "Unhold kubeadm before upgrading"
check "apt-get install.*kubeadm"            "Install new kubeadm version"
check "apt-mark hold kubeadm"              "Hold kubeadm after upgrading"
check "kubeadm upgrade (plan|apply)"       "Run kubeadm upgrade plan or apply"
check "kubeadm upgrade apply v1\.29"       "Apply upgrade to v1.29.x"
check "kubectl drain"                      "Drain node before kubelet upgrade"
check "ignore-daemonsets"                  "Use --ignore-daemonsets with drain"
check "apt-mark unhold kubectl kubelet"    "Unhold kubectl and kubelet"
check "apt-get install.*kubelet"           "Install new kubelet"
check "apt-get install.*kubectl"           "Install new kubectl"
check "systemctl.*restart kubelet"         "Restart kubelet after upgrade"
check "kubectl uncordon"                   "Uncordon node after upgrade"

echo ""
echo "Score: $SCORE/12"
echo ""

if [[ $SCORE -ge 10 ]]; then
  echo "✅ Upgrade plan is correct and complete! (${SCORE}/12 checks passed)"
  exit 0
else
  echo "❌ Upgrade plan is incomplete (${SCORE}/12 checks passed)."
  echo ""
  echo "Missing steps:"
  for issue in "${ISSUES[@]}"; do
    echo "  - $issue"
  done
  exit 1
fi
