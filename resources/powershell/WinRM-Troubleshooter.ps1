# WinRM-Troubleshooter.ps1 - Comprehensive WinRM troubleshooting and setup script
# This script diagnoses and fixes common WinRM issues for remote PowerShell execution

param(
    [Parameter(Mandatory=$true)]
    [string]$RemoteHost,
    
    [Parameter(Mandatory=$false)]
    [string]$RemoteUser,
    
    [Parameter(Mandatory=$false)]
    [securestring]$RemotePassword,
    
    [switch]$FixIssues,
    [switch]$TestOnly
)

Write-Host "=== WinRM Troubleshooter ===" -ForegroundColor Yellow
Write-Host "Target: $RemoteHost" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "Administrator Status: $(if($isAdmin) { 'Yes' } else { 'No' })" -ForegroundColor $(if($isAdmin) { 'Green' } else { 'Yellow' })

if (-not $isAdmin -and $FixIssues) {
    Write-Warning "Administrator privileges required to fix issues. Run as Administrator or use -TestOnly switch."
}

Write-Host ""

# 1. Test Basic Connectivity
Write-Host "1. Testing Basic Connectivity..." -ForegroundColor Cyan
$pingTest = Test-NetConnection -ComputerName $RemoteHost -InformationLevel Quiet -WarningAction SilentlyContinue
Write-Host "   Ping Test: $(if($pingTest) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if($pingTest) { 'Green' } else { 'Red' })

# 2. Test WinRM Ports
Write-Host ""
Write-Host "2. Testing WinRM Ports..." -ForegroundColor Cyan
$httpTest = Test-NetConnection -ComputerName $RemoteHost -Port 5985 -InformationLevel Quiet
$httpsTest = Test-NetConnection -ComputerName $RemoteHost -Port 5986 -InformationLevel Quiet
Write-Host "   HTTP (5985): $(if($httpTest) { 'OPEN' } else { 'CLOSED' })" -ForegroundColor $(if($httpTest) { 'Green' } else { 'Red' })
Write-Host "   HTTPS (5986): $(if($httpsTest) { 'OPEN' } else { 'CLOSED' })" -ForegroundColor $(if($httpsTest) { 'Green' } else { 'Red' })

# 3. Check Local WinRM Configuration
Write-Host ""
Write-Host "3. Checking Local WinRM Configuration..." -ForegroundColor Cyan

# Check WinRM Service
$winrmService = Get-Service WinRM -ErrorAction SilentlyContinue
Write-Host "   WinRM Service: $(if($winrmService) { $winrmService.Status } else { 'NOT FOUND' })" -ForegroundColor $(if($winrmService -and $winrmService.Status -eq 'Running') { 'Green' } elseif($winrmService) { 'Yellow' } else { 'Red' })

if ($FixIssues -and $isAdmin -and $winrmService -and $winrmService.Status -ne 'Running') {
    Write-Host "   Starting WinRM service..." -ForegroundColor Yellow
    Start-Service WinRM
    Write-Host "   WinRM service started" -ForegroundColor Green
}

# Check TrustedHosts
try {
    $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
    $hostInTrusted = $trustedHosts -and $trustedHosts.Value -like "*$RemoteHost*"
    Write-Host "   TrustedHosts: $(if($hostInTrusted) { 'CONFIGURED' } else { 'NEEDS SETUP' })" -ForegroundColor $(if($hostInTrusted) { 'Green' } else { 'Yellow' })
    
    if ($FixIssues -and $isAdmin -and -not $hostInTrusted) {
        Write-Host "   Adding $RemoteHost to TrustedHosts..." -ForegroundColor Yellow
        if ($trustedHosts -and $trustedHosts.Value) {
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$($trustedHosts.Value),$RemoteHost" -Force
        } else {
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value $RemoteHost -Force
        }
        Write-Host "   TrustedHosts updated" -ForegroundColor Green
    }
} catch {
    Write-Host "   TrustedHosts: ERROR - $($_.Exception.Message)" -ForegroundColor Red
}

# Check AllowUnencrypted
try {
    $allowUnencrypted = Get-Item WSMan:\localhost\Client\AllowUnencrypted -ErrorAction SilentlyContinue
    $unencryptedEnabled = $allowUnencrypted -and $allowUnencrypted.Value -eq "true"
    Write-Host "   Unencrypted Traffic: $(if($unencryptedEnabled) { 'ENABLED' } else { 'DISABLED' })" -ForegroundColor $(if($unencryptedEnabled) { 'Green' } else { 'Yellow' })
    
    if ($FixIssues -and $isAdmin -and -not $unencryptedEnabled) {
        Write-Host "   Enabling unencrypted traffic..." -ForegroundColor Yellow
        Set-Item WSMan:\localhost\Client\AllowUnencrypted -Value $true -Force
        Write-Host "   Unencrypted traffic enabled" -ForegroundColor Green
    }
} catch {
    Write-Host "   Unencrypted Traffic: ERROR - $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Test WSMan Connection
Write-Host ""
Write-Host "4. Testing WSMan Connection..." -ForegroundColor Cyan
try {
    $wsmanTest = Test-WSMan -ComputerName $RemoteHost -ErrorAction Stop
    Write-Host "   WSMan Test: PASS" -ForegroundColor Green
    Write-Host "   Remote Version: $($wsmanTest.ProductVersion)" -ForegroundColor Gray
} catch {
    Write-Host "   WSMan Test: FAIL - $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Test PowerShell Remoting (if credentials provided)
if (-not [string]::IsNullOrEmpty($RemoteUser) -and $RemotePassword) {
    Write-Host ""
    Write-Host "5. Testing PowerShell Remoting with Credentials..." -ForegroundColor Cyan
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential($RemoteUser, $RemotePassword)
        
        $session = New-PSSession -ComputerName $RemoteHost -Credential $credential -ErrorAction Stop
        Write-Host "   Remote Session: PASS" -ForegroundColor Green
        
        # Test a simple command
        $result = Invoke-Command -Session $session -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
        Write-Host "   Remote Command Test: PASS (Connected to: $result)" -ForegroundColor Green
        
        Remove-PSSession $session
    } catch {
        Write-Host "   Remote Session: FAIL - $($_.Exception.Message)" -ForegroundColor Red
        
        # Try with basic authentication
        try {
            Write-Host "   Trying with Basic Authentication..." -ForegroundColor Yellow
            $session = New-PSSession -ComputerName $RemoteHost -Credential $credential -Authentication Basic -ErrorAction Stop
            Write-Host "   Basic Auth Session: PASS" -ForegroundColor Green
            Remove-PSSession $session
        } catch {
            Write-Host "   Basic Auth Session: FAIL - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 6. Recommendations
Write-Host ""
Write-Host "=== Recommendations ===" -ForegroundColor Yellow

if (-not $pingTest) {
    Write-Host "! Check network connectivity to $RemoteHost" -ForegroundColor Red
}

if (-not $httpTest -and -not $httpsTest) {
    Write-Host "! WinRM ports are blocked. On $RemoteHost, run:" -ForegroundColor Red
    Write-Host "  winrm quickconfig -y" -ForegroundColor White
    Write-Host "  Enable-PSRemoting -Force" -ForegroundColor White
    Write-Host "  New-NetFirewallRule -DisplayName 'WinRM HTTP' -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow" -ForegroundColor White
}

if (-not $isAdmin) {
    Write-Host "! Run this script as Administrator to apply fixes automatically" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Yellow
Write-Host "Use this information to configure WinRM properly for remote PowerShell execution."
Write-Host ""

# Quick fix commands
if ($isAdmin -and $FixIssues) {
    Write-Host "=== Applied Fixes ===" -ForegroundColor Green
    Write-Host "Local WinRM configuration has been updated where possible."
    Write-Host "Remote host configuration must be done manually on $RemoteHost"
    Write-Host ""
}

Write-Host "Quick commands to run on REMOTE HOST ($RemoteHost) as Administrator:" -ForegroundColor Cyan
Write-Host "Enable-PSRemoting -Force -SkipNetworkProfileCheck" -ForegroundColor White
Write-Host "winrm quickconfig -y" -ForegroundColor White
Write-Host "Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force" -ForegroundColor White
Write-Host ""