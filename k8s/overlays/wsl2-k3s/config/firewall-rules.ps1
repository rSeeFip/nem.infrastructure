# Windows Firewall Rules for WSL2 K3s Deployment
# 
# This script configures Windows Firewall to allow inbound traffic
# to ports used by K3s services running in WSL2 with mirrored networking.
#
# Usage: Run as Administrator
#   powershell -ExecutionPolicy Bypass -File firewall-rules.ps1
#
# IMPORTANT: Execute this script with Administrator privileges!

#Requires -RunAsAdministrator

# Define color functions for output
function Write-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[i] $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator!"
    Write-Info "Please restart PowerShell as Administrator and try again."
    exit 1
}

Write-Info "Configuring Windows Firewall for WSL2 K3s..."
Write-Info ""

# Define ports for K3s services
# Format: @{Port = Port Number; Description = Service Name}
$ports = @(
    @{Port = 80;     Description = "HTTP / PgAdmin / Gateway"}
    @{Port = 443;    Description = "HTTPS"}
    @{Port = 3000;   Description = "nem.Web / Grafana"}
    @{Port = 5000;   Description = "MCP (Python services)"}
    @{Port = 5100;   Description = "KnowHub"}
    @{Port = 5223;   Description = "Mimir"}
    @{Port = 5300;   Description = "Classification"}
    @{Port = 5400;   Description = "Comms"}
    @{Port = 5500;   Description = "Backup"}
    @{Port = 5600;   Description = "Scheduler"}
    @{Port = 5700;   Description = "MediaHub"}
    @{Port = 5800;   Description = "HomeAssistant"}
    @{Port = 8080;   Description = "Keycloak"}
    @{Port = 8200;   Description = "OpenBao (Vault)"}
    @{Port = 9090;   Description = "Prometheus"}
    @{Port = 15672;  Description = "RabbitMQ Management"}
)

$errorCount = 0
$successCount = 0

Write-Info "Creating firewall rules for WSL2 services..."
Write-Info ""

foreach ($portConfig in $ports) {
    $port = $portConfig.Port
    $description = $portConfig.Description
    $ruleName = "WSL2-K3s-Port-$port"
    
    try {
        # Check if rule already exists
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Write-Warning "Rule already exists for port $port ($description) - Updating..."
            Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Out-Null
        }
        
        # Create new firewall rule
        New-NetFirewallRule `
            -DisplayName $ruleName `
            -Description "Allow WSL2 K3s service: $description" `
            -Direction Inbound `
            -Action Allow `
            -Protocol TCP `
            -LocalPort $port `
            -Program Any `
            -ErrorAction Stop | Out-Null
        
        Write-Success "Port $port ($description)"
        $successCount++
    }
    catch {
        Write-Error "Failed to create rule for port $port: $_"
        $errorCount++
    }
}

Write-Info ""
Write-Info "Summary: $successCount rules created, $errorCount errors"

if ($errorCount -eq 0) {
    Write-Success "All firewall rules configured successfully!"
    Write-Info ""
    Write-Info "Windows Firewall is now configured to allow inbound traffic to WSL2 K3s services."
    Write-Info "You can now access services via: http://{service}.nem.local"
} else {
    Write-Warning "Some firewall rules may not have been created. Please check the errors above."
    exit 1
}

Write-Info ""
Write-Info "Next steps:"
Write-Info "1. Add hosts file entries from: infrastructure/k8s/overlays/wsl2-k3s/config/hosts-entries.txt"
Write-Info "2. In WSL2, run: bash infrastructure/k8s/overlays/wsl2-k3s/scripts/setup-wsl2.sh"
