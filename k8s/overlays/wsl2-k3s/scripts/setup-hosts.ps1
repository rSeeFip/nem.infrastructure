# setup-hosts.ps1 - Add nem.local entries to Windows hosts file
# Run as Administrator: powershell -ExecutionPolicy Bypass -File setup-hosts.ps1

$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$entries = @(
    "127.0.0.1 keycloak.nem.local",
    "127.0.0.1 grafana.nem.local",
    "127.0.0.1 prometheus.nem.local",
    "127.0.0.1 pgadmin.nem.local",
    "127.0.0.1 rabbitmq.nem.local",
    "127.0.0.1 openbao.nem.local",
    "127.0.0.1 gateway.nem.local",
    "127.0.0.1 mcp.nem.local",
    "127.0.0.1 mcp-ui.nem.local",
    "127.0.0.1 knowhub.nem.local",
    "127.0.0.1 mimir.nem.local",
    "127.0.0.1 classification.nem.local",
    "127.0.0.1 comms.nem.local",
    "127.0.0.1 web.nem.local",
    "127.0.0.1 homeassistant.nem.local",
    "127.0.0.1 backup.nem.local"
)

$windowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($windowsIdentity)
$isAdministrator = $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdministrator) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

if (-not (Test-Path $hostsFile)) {
    Write-Error "Hosts file not found: $hostsFile"
    exit 1
}

$existingEntries = Get-Content -Path $hostsFile -ErrorAction Stop
$entriesToAdd = @()

foreach ($entry in $entries) {
    if ($existingEntries -notcontains $entry) {
        $entriesToAdd += $entry
    }
}

if ($entriesToAdd.Count -eq 0) {
    Write-Host "All nem.local hosts entries already exist."
    exit 0
}

Add-Content -Path $hostsFile -Value ""
Add-Content -Path $hostsFile -Value "# nem.local development endpoints"
Add-Content -Path $hostsFile -Value $entriesToAdd

Write-Host "Added $($entriesToAdd.Count) nem.local hosts entries to $hostsFile"
