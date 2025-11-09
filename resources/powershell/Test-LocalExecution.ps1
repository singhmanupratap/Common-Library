# Test-LocalExecution.ps1 - Simple test script to verify the shared library works locally
# This bypasses all remote connection issues for testing the core functionality

param(
    [Parameter(Mandatory=$true)]
    [string]$RemoteFile,
    
    [hashtable]$AdditionalParams = @{}
)

Write-Host "=== Local Test Execution ===" -ForegroundColor Green
Write-Host "Test File: $RemoteFile"
Write-Host "Parameters: $($AdditionalParams | Out-String)"

# Check if the file exists
if (-not (Test-Path $RemoteFile)) {
    Write-Error "Test file not found: $RemoteFile"
    exit 1
}

Write-Host ""
Write-Host "Executing file locally..." -ForegroundColor Cyan

try {
    # Build parameter string
    $paramString = ""
    if ($AdditionalParams.Count -gt 0) {
        foreach ($key in $AdditionalParams.Keys) {
            $value = $AdditionalParams[$key]
            $paramString += " -$key '$value'"
        }
    }
    
    # Execute the script
    $command = "& '$RemoteFile'$paramString"
    Write-Host "Command: $command" -ForegroundColor Gray
    Write-Host ""
    
    $null = Invoke-Expression $command
    
    Write-Host ""
    Write-Host "=== Execution Completed Successfully ===" -ForegroundColor Green
    
    return @{
        Status = "Success"
        ComputerName = $env:COMPUTERNAME
        User = $env:USERNAME
        Method = "Local Test Execution"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Parameters = $AdditionalParams
    }
}
catch {
    Write-Error "Local execution failed: $($_.Exception.Message)"
    throw
}