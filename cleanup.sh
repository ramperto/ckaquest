#!/bin/bash

# CKAQuest - Cleanup Script
# Removes game state, optionally removes installation

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "  ██████ ██   ██  █████  ██████  ██    ██ ███████ ███████ ████████ "
echo " ██      ██  ██  ██   ██ ██   ██ ██    ██ ██      ██         ██    "
echo " ██      █████   ███████ ██████  ██    ██ █████   ███████    ██    "
echo " ██      ██  ██  ██   ██ ██      ██    ██ ██           ██    ██    "
echo "  ██████ ██   ██ ██   ██ ██       ██████  ███████ ███████    ██    "
echo -e "${NC}"
echo -e "${BOLD}CKAQuest - Cleanup Script${NC}"
echo "=================================================="
echo ""

# Parse arguments
CLEAN_MODE="soft"  # soft (default) or full
if [[ "$1" == "--full" ]]; then
  CLEAN_MODE="full"
  echo -e "${YELLOW}WARNING: Full cleanup mode will remove k3s, kubectl, and etcdctl${NC}"
  echo ""
fi

# ── Soft Cleanup: Just the game state ────────────────────────────────────────

echo -e "${BOLD}[1/3] Cleaning up ckaquest namespace...${NC}"
if kubectl get namespace ckaquest &>/dev/null 2>&1; then
  kubectl delete namespace ckaquest --ignore-not-found=true
  echo -e "  ${GREEN}✓${NC} ckaquest namespace deleted"
else
  echo -e "  ${GREEN}✓${NC} ckaquest namespace already gone"
fi

echo ""
echo -e "${BOLD}[2/3] Removing game progress...${NC}"
if [[ -f "progress.json" ]]; then
  rm progress.json
  echo -e "  ${GREEN}✓${NC} progress.json deleted"
else
  echo -e "  ${GREEN}✓${NC} progress.json not found"
fi

echo ""
echo -e "${BOLD}[3/3] Removing Python virtual environment...${NC}"
if [[ -d "venv" ]]; then
  rm -rf venv
  echo -e "  ${GREEN}✓${NC} venv/ deleted"
else
  echo -e "  ${GREEN}✓${NC} venv/ not found"
fi

# ── Full Cleanup: Remove everything (k3s, kubectl, etcdctl) ───────────────────

if [[ "$CLEAN_MODE" == "full" ]]; then
  echo ""
  echo -e "${YELLOW}${BOLD}Proceeding with FULL cleanup...${NC}"
  echo ""

  echo -e "${BOLD}[4/7] Stopping k3s...${NC}"
  if command -v k3s &>/dev/null; then
    sudo systemctl stop k3s 2>/dev/null || true
    sudo systemctl disable k3s 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} k3s stopped"
  fi

  echo ""
  echo -e "${BOLD}[5/7] Removing k3s...${NC}"
  if [[ -f "/usr/local/bin/k3s-uninstall.sh" ]]; then
    sudo /usr/local/bin/k3s-uninstall.sh
    echo -e "  ${GREEN}✓${NC} k3s uninstalled"
  else
    echo -e "  ${YELLOW}⚠${NC} k3s uninstall script not found"
  fi

  echo ""
  echo -e "${BOLD}[6/7] Removing kubectl...${NC}"
  if [[ -f "/usr/local/bin/kubectl" ]]; then
    sudo rm /usr/local/bin/kubectl
    echo -e "  ${GREEN}✓${NC} kubectl removed"
  fi

  echo ""
  echo -e "${BOLD}[7/7] Removing etcdctl...${NC}"
  if [[ -f "/usr/local/bin/etcdctl" ]]; then
    sudo rm /usr/local/bin/etcdctl
    echo -e "  ${GREEN}✓${NC} etcdctl removed"
  fi

  echo ""
  echo -e "${YELLOW}Note: kubeconfig (~/.kube/config) was NOT deleted.${NC}"
  echo -e "      Remove it manually if needed: ${CYAN}rm ~/.kube/config${NC}"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}=================================================="
if [[ "$CLEAN_MODE" == "soft" ]]; then
  echo "  Soft cleanup complete!"
  echo "  (Game state removed, k3s/kubectl/etcdctl remain)"
  echo ""
  echo "  To reinstall the game: ./install.sh"
  echo "  To do a full cleanup: ./cleanup.sh --full"
else
  echo "  Full cleanup complete!"
  echo "  (All CKAQuest components removed)"
  echo ""
  echo "  To reinstall everything: ./install.sh"
fi
echo -e "==================================================${NC}"
echo ""
