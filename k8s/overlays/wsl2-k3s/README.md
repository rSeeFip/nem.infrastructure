# WSL2 K3s Configuration Suite

Complete configuration and installation scripts for deploying Kubernetes (K3s) on Windows Subsystem for Linux 2 (WSL2) with mirrored networking.

## Overview

This package provides:
1. **WSL2 systemd configuration** - Enables systemd support required for K3s
2. **K3s installation script** - Automated K3s deployment with verification
3. **Windows firewall rules** - PowerShell script to allow K3s service traffic
4. **Windows hosts file entries** - DNS resolution for .nem.local domains
5. **WSL2 configuration template** - Mirrored networking and resource allocation

## Quick Start

### Prerequisites
- Windows 10/11 with WSL2 enabled
- WSL2 distribution installed (Ubuntu recommended)
- Administrator access on Windows
- 8GB+ available RAM (recommended)
- 4+ CPU cores (recommended)

### Installation Steps

#### Step 1: Configure Windows Firewall (PowerShell as Administrator)

```powershell
cd nem.infrastructure/k8s/overlays/wsl2-k3s/config
powershell -ExecutionPolicy Bypass -File firewall-rules.ps1
```

This opens inbound traffic to 16 ports required by K3s services.

#### Step 2: Add DNS Entries (Notepad as Administrator)

1. Open Notepad as Administrator
2. File → Open → Navigate to `C:\Windows\System32\drivers\etc\hosts`
3. Copy entries from `hosts-entries.txt` (lines starting with `127.0.0.1`)
4. Paste at the end of the hosts file
5. Save and close

#### Step 3: Configure WSL2 (.wslconfig)

1. Copy `wslconfig` to `%USERPROFILE%\.wslconfig`
   ```cmd
   copy config\wslconfig %USERPROFILE%\.wslconfig
   ```
2. Shut down WSL2:
   ```cmd
   wsl --shutdown
   ```

#### Step 4: Install K3s (WSL2 terminal)

```bash
cd nem.infrastructure/k8s/overlays/wsl2-k3s
bash scripts/setup-wsl2.sh
```

The script will:
- Enable systemd support in WSL2
- Install K3s
- Wait for cluster readiness
- Verify Traefik ingress controller
- Verify local-path storage class
- Configure kubectl access

#### Step 5: Verify Services

After installation completes, test access:

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Access services (requires DNS entries in hosts file)
curl http://web.nem.local
curl http://grafana.nem.local
```

## File Descriptions

### scripts/setup-wsl2.sh
Bash script that:
- Enables systemd in `/etc/wsl.conf`
- Updates system packages
- Installs K3s with `--write-kubeconfig-mode 644`
- Waits for cluster readiness (max 60 attempts)
- Verifies Traefik ingress controller
- Verifies local-path storage class
- Configures kubectl for current user
- Displays cluster status

**Error Handling:** Uses `set -euo pipefail` and checks all critical operations

### config/wslconfig
WSL2 configuration template containing:
- `[wsl2]` section with mirrored networking
- Memory: 8GB (adjust as needed)
- Processors: 4 (adjust as needed)
- Swap: 2GB (optional)
- localhost forwarding enabled
- `[interop]` settings for file/command access
- `[boot]` systemd support

**Deployment:** Place at `%USERPROFILE%\.wslconfig` before restarting WSL2

### config/firewall-rules.ps1
PowerShell script that:
- Requires Administrator privileges
- Creates firewall rules for 16 ports
- Uses `New-NetFirewallRule` cmdlet
- Direction: Inbound, Action: Allow, Protocol: TCP
- Includes error handling and reporting

**Ports:** 80, 443, 3000, 5000, 5100, 5223, 5300, 5400, 5500, 5600, 5700, 5800, 8080, 8200, 9090, 15672

### config/hosts-entries.txt
Windows hosts file additions for:
- web.nem.local
- mcp.nem.local
- knowhub.nem.local
- mimir.nem.local
- classification.nem.local
- comms.nem.local
- backup.nem.local
- scheduler.nem.local
- mediahub.nem.local
- homeassistant.nem.local
- keycloak.nem.local
- grafana.nem.local
- prometheus.nem.local
- pgadmin.nem.local
- rabbitmq.nem.local
- openbao.nem.local
- gateway.nem.local
- configuration.nem.local

All entries resolve to `127.0.0.1` via mirrored networking.

## Troubleshooting

### K3s not starting
```bash
# Check systemd in WSL2
cat /etc/wsl.conf | grep systemd

# View K3s logs
sudo journalctl -u k3s -f

# Check if K3s service is running
sudo systemctl status k3s
```

### Services not accessible from Windows
1. Verify firewall rules created: `Get-NetFirewallRule -DisplayName "WSL2-K3s-Port-*" | Select-Object DisplayName, Direction, Action`
2. Check hosts file entries: `type C:\Windows\System32\drivers\etc\hosts | findstr .nem.local`
3. Verify WSL2 mirrored networking: Check `.wslconfig` has `networkingMode=mirrored`

### kubectl not found
Ensure kubectl permissions:
```bash
ls -la ~/.kube/config
chmod 600 ~/.kube/config
```

## Resource Requirements

- **Memory:** 8GB WSL2 VM (adjust in `.wslconfig` if needed)
- **CPU:** 4 cores (adjust in `.wslconfig` if needed)
- **Disk:** 20GB minimum for K3s and container images
- **Network:** Requires access to Docker Hub / container registries

## K3s Components

K3s automatically provides:
- **Ingress Controller:** Traefik (included)
- **Storage:** local-path provisioner (for development)
- **Container Runtime:** containerd
- **Package Manager:** Helm (optional)

## Next Steps

1. Deploy application manifests using kubectl or Helm
2. Configure custom ingress routes through Traefik
3. Monitor cluster with Prometheus/Grafana
4. Set up persistent storage if needed

## Support

For K3s documentation: https://docs.k3s.io/
For WSL2 documentation: https://learn.microsoft.com/en-us/windows/wsl/

## License & Attribution

WSL2 K3s Configuration Suite
Created for nem.Reflect infrastructure deployment
