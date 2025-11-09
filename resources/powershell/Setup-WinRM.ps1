# Setup-WinRM.ps1 - Helper script to configure WinRM for remote PowerShell execution
# This script must be run as Administrator

param(
    [Parameter(Mandatory=$true)]
    [string]$RemoteHost,
    
    [switch]$EnableRemoting,
    [switch]$TestConnection
)

Write-Host "=== WinRM Configuration Helper ===" -ForegroundColor Yellow
Write-Host "Target Remote Host: $RemoteHost" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "This script must be run as Administrator to configure WinRM settings."
    Write-Host "Please run PowerShell as Administrator and execute this script again."
    exit 1
}

Write-Host "Running with Administrator privileges ✓" -ForegroundColor Green
Write-Host ""

# Enable PS Remoting if requested
if ($EnableRemoting) {
    Write-Host "1. Enabling PowerShell Remoting..." -ForegroundColor Cyan
    try {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck
        Write-Host "   PowerShell Remoting enabled ✓" -ForegroundColor Green
    }
    catch {
        Write-Error "   Failed to enable PowerShell Remoting: $($_.Exception.Message)"
    }
    Write-Host ""
}

# Configure TrustedHosts
Write-Host "2. Configuring TrustedHosts..." -ForegroundColor Cyan
try {
    $currentTrustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
    
    if ($currentTrustedHosts -and $currentTrustedHosts.Value -like "*$RemoteHost*") {
        Write-Host "   $RemoteHost is already in TrustedHosts ✓" -ForegroundColor Green
    } else {
        if ($currentTrustedHosts -and $currentTrustedHosts.Value) {
            $newValue = "$($currentTrustedHosts.Value),$RemoteHost"
        } else {
            $newValue = $RemoteHost
        }
        
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $newValue -Force
        Write-Host "   Added $RemoteHost to TrustedHosts ✓" -ForegroundColor Green
        Write-Host "   Current TrustedHosts: $newValue" -ForegroundColor Gray
    }
}
catch {
    Write-Error "   Failed to configure TrustedHosts: $($_.Exception.Message)"
}
Write-Host ""

# Check WinRM service
Write-Host "3. Checking WinRM service..." -ForegroundColor Cyan
try {
    $winrmService = Get-Service WinRM
    Write-Host "   WinRM Service Status: $($winrmService.Status)" -ForegroundColor $(if($winrmService.Status -eq 'Running') { 'Green' } else { 'Yellow' })
    
    if ($winrmService.Status -ne 'Running') {
        Write-Host "   Starting WinRM service..." -ForegroundColor Yellow
        Start-Service WinRM
        Write-Host "   WinRM service started ✓" -ForegroundColor Green
    }
}
catch {
    Write-Error "   Failed to check/start WinRM service: $($_.Exception.Message)"
}
Write-Host ""

# Test connectivity if requested
if ($TestConnection) {
    Write-Host "4. Testing connectivity to $RemoteHost..." -ForegroundColor Cyan
    
    # Test HTTP port (5985)
    $httpTest = Test-NetConnection -ComputerName $RemoteHost -Port 5985 -InformationLevel Quiet
    Write-Host "   HTTP (5985): $(if($httpTest) { '✓ Open' } else { '✗ Blocked' })" -ForegroundColor $(if($httpTest) { 'Green' } else { 'Red' })
    
    # Test HTTPS port (5986)
    $httpsTest = Test-NetConnection -ComputerName $RemoteHost -Port 5986 -InformationLevel Quiet
    Write-Host "   HTTPS (5986): $(if($httpsTest) { '✓ Open' } else { '✗ Blocked' })" -ForegroundColor $(if($httpsTest) { 'Green' } else { 'Red' })
    
    # Test WSMan
    try {
        $wsmanTest = Test-WSMan -ComputerName $RemoteHost -ErrorAction Stop
        Write-Host "   WSMan Test: ✓ Success" -ForegroundColor Green
        Write-Host "   Remote PowerShell Version: $($wsmanTest.ProductVersion)" -ForegroundColor Gray
    }
    catch {
        Write-Host "   WSMan Test: ✗ Failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Configuration Summary ===" -ForegroundColor Yellow
Write-Host "Local WinRM setup for remote host '$RemoteHost' is complete."
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Ensure the target machine ($RemoteHost) also has PowerShell Remoting enabled"
Write-Host "2. Run the following on $RemoteHost (as Administrator):"
Write-Host "   Enable-PSRemoting -Force"
Write-Host "   winrm quickconfig -y"
Write-Host ""
Write-Host "3. Test the connection:"
Write-Host "   Enter-PSSession -ComputerName $RemoteHost -Credential (Get-Credential)"
Write-Host ""

# Usage examples
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  Setup-WinRM.ps1 -RemoteHost '192.168.1.120' -EnableRemoting -TestConnection"
Write-Host "  Setup-WinRM.ps1 -RemoteHost 'server01' -EnableRemoting"
Write-Host ""