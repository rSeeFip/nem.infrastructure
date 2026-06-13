#!/bin/bash
# WSL2 + K3s Setup Script
# This script configures WSL2 for K3s deployment with systemd and installs K3s

set -euo pipefail

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Step 1: Enable systemd in WSL2
log_info "Configuring WSL2 systemd support..."
if grep -q "^\[boot\]" /etc/wsl.conf 2>/dev/null; then
    # If [boot] section exists, update or add systemd=true
    if grep -q "systemd=true" /etc/wsl.conf; then
        log_info "systemd already enabled in /etc/wsl.conf"
    else
        sudo sed -i '/^\[boot\]/a systemd=true' /etc/wsl.conf
        log_warn "systemd enabled - WSL2 restart required after K3s setup"
    fi
else
    # Create [boot] section with systemd=true
    echo -e "\n[boot]\nsystemd=true" | sudo tee -a /etc/wsl.conf > /dev/null
    log_warn "systemd enabled in new [boot] section - WSL2 restart required after K3s setup"
fi

# Step 2: Update and install prerequisites
log_info "Updating package lists..."
sudo apt-get update -qq

log_info "Installing prerequisite packages..."
sudo apt-get install -y -qq \
    curl \
    wget \
    git \
    jq \
    net-tools \
    htop \
    > /dev/null 2>&1

# Step 3: Install K3s
log_info "Installing K3s..."
if command -v k3s &> /dev/null; then
    log_warn "K3s already installed"
else
    # Install K3s with write permissions for kubeconfig
    curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 || log_error "K3s installation failed"
    log_info "K3s installed successfully"
fi

# Step 4: Wait for K3s to be ready
log_info "Waiting for K3s cluster to be ready..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        
        # Check if node is ready
        if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
            log_info "Kubernetes node is Ready"
            break
        fi
    fi
    
    attempt=$((attempt + 1))
    echo -ne "\rWaiting... ($attempt/$max_attempts)"
    sleep 1
done

if [ $attempt -eq $max_attempts ]; then
    log_error "K3s failed to become ready within timeout"
fi
echo ""

# Step 5: Verify cluster components
log_info "Verifying cluster components..."

# Check Traefik ingress controller
if kubectl get deployment -n kube-system traefik 2>/dev/null | grep -q traefik; then
    log_info "✓ Traefik ingress controller is running"
else
    log_warn "Traefik ingress controller not found"
fi

# Check local-path storage class
if kubectl get storageclass local-path 2>/dev/null | grep -q local-path; then
    log_info "✓ local-path storage class is available"
else
    log_warn "local-path storage class not found"
fi

# Step 6: Configure kubectl for current user
log_info "Configuring kubectl for current user..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config
chmod 600 ~/.kube/config

# Verify kubectl works
if kubectl cluster-info &>/dev/null; then
    log_info "✓ kubectl configured and working"
else
    log_error "kubectl configuration failed"
fi

# Step 7: Display cluster status
log_info "Cluster status:"
kubectl get nodes -o wide
log_info ""
kubectl get pods -n kube-system -o wide | head -10

log_info "K3s setup complete!"
log_info ""
log_info "Next steps:"
log_info "1. In PowerShell (admin), run: nem.infrastructure/k8s/overlays/wsl2-k3s/config/firewall-rules.ps1"
log_info "2. In Notepad (admin), add hosts file entries from nem.infrastructure/k8s/overlays/wsl2-k3s/config/hosts-entries.txt"
log_info "3. If systemd was newly enabled, restart WSL2: wsl --terminate Distribution"
log_info ""
log_info "Access K3s API at: https://127.0.0.1:6443"
log_info "Access services via: http://{service}.nem.local"
