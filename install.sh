#!/bin/bash
set -e

# CKAQuest - CKA Exam Preparation Game
# Installer for Ubuntu VPS (k3s-based)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

NAMESPACE="ckaquest"

echo -e "${CYAN}${BOLD}"
echo "  ██████ ██   ██  █████  ██████  ██    ██ ███████ ███████ ████████ "
echo " ██      ██  ██  ██   ██ ██   ██ ██    ██ ██      ██         ██    "
echo " ██      █████   ███████ ██████  ██    ██ █████   ███████    ██    "
echo " ██      ██  ██  ██   ██ ██      ██    ██ ██           ██    ██    "
echo "  ██████ ██   ██ ██   ██ ██       ██████  ███████ ███████    ██    "
echo -e "${NC}"
echo -e "${BOLD}CKA Exam Preparation Platform${NC}"
echo "=================================================="
echo ""

# ── Check OS ────────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Linux" ]]; then
  echo -e "${RED}ERROR: CKAQuest requires Ubuntu/Linux.${NC}"
  echo "  This installer is designed for Ubuntu VPS environments."
  exit 1
fi

echo -e "${BOLD}[1/6] Checking prerequisites...${NC}"

check_cmd() {
  if command -v "$1" &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $1 found"
  else
    echo -e "  ${RED}✗${NC} $1 not found — $2"
    MISSING="$MISSING $1"
  fi
}

MISSING=""
check_cmd curl "required to install k3s"
check_cmd python3 "install with: sudo apt install python3"
check_cmd jq "install with: sudo apt install jq"

if [[ -n "$MISSING" ]]; then
  echo ""
  echo -e "${YELLOW}Installing missing system packages...${NC}"
  sudo apt-get update -qq
  for pkg in $MISSING; do
    sudo apt-get install -y -qq "$pkg"
  done
fi

# ── Python version check ─────────────────────────────────────────────────────
PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)

if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 9 ]]; then
  echo -e "${RED}ERROR: Python 3.9+ required (found $PY_VERSION)${NC}"
  echo "  sudo apt install python3.11"
  exit 1
fi
echo -e "  ${GREEN}✓${NC} Python $PY_VERSION"

# ── Install/verify kubectl ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}[2/6] Setting up kubectl...${NC}"

if ! command -v kubectl &>/dev/null; then
  echo "  Installing kubectl..."
  curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
  echo -e "  ${GREEN}✓${NC} kubectl installed"
else
  echo -e "  ${GREEN}✓${NC} kubectl found"
fi

# ── Install k3s ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}[3/6] Setting up k3s (lightweight Kubernetes)...${NC}"

if ! command -v k3s &>/dev/null; then
  echo "  Installing k3s with embedded etcd (this may take a minute)..."
  # --cluster-init enables embedded etcd (required for etcd backup/restore levels)
  # --kubelet-arg sets static pod path to match CKA exam environment
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init \
    --kubelet-arg=pod-manifest-path=/etc/kubernetes/manifests \
    --write-kubeconfig-mode=644" sh -
  echo -e "  ${GREEN}✓${NC} k3s installed (embedded etcd + static pod support)"
else
  echo -e "  ${GREEN}✓${NC} k3s already installed"
fi

# Ensure static pod manifests directory exists (mirrors CKA exam environment)
sudo mkdir -p /etc/kubernetes/manifests
echo -e "  ${GREEN}✓${NC} Static pod manifest path: /etc/kubernetes/manifests"

# Install etcdctl for etcd backup/restore exercises
if ! command -v etcdctl &>/dev/null; then
  echo "  Installing etcdctl..."
  ETCD_VER="v3.5.9"
  curl -sL "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz" \
    | sudo tar -xz -C /usr/local/bin --strip-components=1 \
        "etcd-${ETCD_VER}-linux-amd64/etcdctl"
  echo -e "  ${GREEN}✓${NC} etcdctl installed"
fi

# Wait for k3s to be ready
echo "  Waiting for k3s to be ready..."
for i in {1..30}; do
  if k3s kubectl get nodes &>/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# ── Configure kubeconfig ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}[4/6] Configuring kubeconfig...${NC}"

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u)":"$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config

# Verify kubectl works
if kubectl get nodes &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} kubectl configured successfully"
  NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}')
  echo -e "  ${GREEN}✓${NC} Node status: $NODE_STATUS"
else
  echo -e "${RED}ERROR: kubectl cannot connect to cluster${NC}"
  exit 1
fi

# ── Create namespace + RBAC ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}[5/6] Setting up ckaquest namespace and RBAC...${NC}"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo -e "  ${GREEN}✓${NC} Namespace '$NAMESPACE' ready"

kubectl apply -f "$(dirname "$0")/rbac/ckaquest-rbac.yaml" &>/dev/null
echo -e "  ${GREEN}✓${NC} RBAC configured"

# ── Python virtualenv ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}[6/6] Setting up Python environment...${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

python3 -m venv venv
venv/bin/pip install -q --upgrade pip
venv/bin/pip install -q -r requirements.txt
echo -e "  ${GREEN}✓${NC} Python dependencies installed"

echo ""
echo -e "${GREEN}${BOLD}=================================================="
echo "  CKAQuest is ready!"
echo "==================================================${NC}"
echo ""
echo "  Start playing:"
echo -e "  ${CYAN}./play.sh${NC}"
echo ""
echo "  50 levels across 5 CKA exam domains."
echo "  World 1: Troubleshooting (30%)   — 15 levels"
echo "  World 2: Cluster Architecture (25%) — 10 levels"
echo ""
