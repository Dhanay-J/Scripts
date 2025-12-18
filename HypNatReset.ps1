# ==============================
# Reset Hyper-V NAT Switch
# Switch Name : HypNat
# IP Range    : 192.168.56.0/24
# Gateway IP  : 192.168.56.1
# ==============================

# --------- ADMIN CHECK ----------
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "⚠ Administrator privileges required. Relaunching with elevation..." -ForegroundColor Yellow

    Start-Process powershell `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs

    exit
}

Write-Host "`n=== Hyper-V NAT Reset Script ===" -ForegroundColor Cyan

# --------- VARIABLES ----------
$switchName = "HypNat"
$gatewayIP  = "192.168.56.1"
$prefix     = 24
$subnet     = "192.168.56.0/24"
$ifaceAlias = "vEthernet ($switchName)"

# --------- REMOVE EXISTING NAT ----------
Write-Host "`n[1/5] Removing existing NetNAT (if any)..." -ForegroundColor Yellow
Get-NetNat -ErrorAction SilentlyContinue | Remove-NetNat -Confirm:$false

# --------- REMOVE EXISTING SWITCH ----------
Write-Host "[2/5] Removing existing Hyper-V switch '$switchName' (if any)..." -ForegroundColor Yellow
if (Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue) {
    Remove-VMSwitch -Name $switchName -Force
}

# --------- CREATE SWITCH ----------
Write-Host "[3/5] Creating new Internal Hyper-V switch '$switchName'..." -ForegroundColor Green
New-VMSwitch -Name $switchName -SwitchType Internal | Out-Null

Start-Sleep -Seconds 2   # allow vEthernet interface to appear

# --------- ASSIGN IP ----------
Write-Host "[4/5] Assigning IP $gatewayIP/$prefix to '$ifaceAlias'..." -ForegroundColor Green

# Remove old IPs if present
Get-NetIPAddress -InterfaceAlias $ifaceAlias -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false

New-NetIPAddress `
    -IPAddress $gatewayIP `
    -PrefixLength $prefix `
    -InterfaceAlias $ifaceAlias | Out-Null

# --------- CREATE NAT ----------
Write-Host "[5/5] Creating NetNAT for $subnet..." -ForegroundColor Green
New-NetNat -Name $switchName -InternalIPInterfaceAddressPrefix $subnet | Out-Null

# --------- DONE ----------
Write-Host "`n✅ Hyper-V NAT reset completed successfully." -ForegroundColor Cyan
Write-Host "➡ Attach your VMs to '$switchName' and set gateway to $gatewayIP"
