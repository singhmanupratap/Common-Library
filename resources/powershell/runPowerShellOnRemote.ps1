param(
    [Parameter(Mandatory=$false)]
    [string]$RemoteHost,
    
    [Parameter(Mandatory=$false)]
    [string]$RemoteUser,
    
    [Parameter(Mandatory=$false)]
    [string]$RemotePassword,
    
    [Parameter(Mandatory=$false)]
    [string]$RemoteFile
)

# Function to execute commands locally or remotely using Invoke-Command
function Execute-PowerShellCommand {
    param(
        [string]$RemoteHost,
        [string]$RemoteUser,
        [string]$RemotePassword,
        [string]$RemoteFile,
        [hashtable]$AdditionalParams = @{}
    )
    
    # Determine execution mode
    $isRemoteExecution = -not [string]::IsNullOrEmpty($RemoteHost)
    
    if ($isRemoteExecution) {
        Write-Host "=== Remote Execution on: $RemoteHost ==="
        
        # Create session configuration
        $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck
        $session = $null
        
        try {
            # Create session based on authentication method
            if (-not [string]::IsNullOrEmpty($RemoteUser) -and -not [string]::IsNullOrEmpty($RemotePassword)) {
                Write-Host "Using provided credentials for authentication"
                $securePassword = ConvertTo-SecureString $RemotePassword -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential($RemoteUser, $securePassword)
                $session = New-PSSession -ComputerName $RemoteHost -Credential $credential -SessionOption $sessionOptions
            } else {
                Write-Host "Using current user credentials for authentication"
                $session = New-PSSession -ComputerName $RemoteHost -SessionOption $sessionOptions
            }
            
            # Execute based on RemoteFile parameter
            if (-not [string]::IsNullOrEmpty($RemoteFile)) {
                Write-Host "Processing remote file: $RemoteFile"
                
                # Generate UNC path from RemoteFile
                $uncPath = $RemoteFile
                
                # Check if RemoteFile is already a UNC path or absolute path
                if ($RemoteFile -notlike "\\*" -and $RemoteFile -notlike "*:*") {
                    # Convert relative path to UNC path
                    # Replace C:\ with \\RemoteHost\C$\ format
                    $uncPath = "\\$RemoteHost\C$\$($RemoteFile.TrimStart('\'))"
                    Write-Host "Generated UNC path: $uncPath"
                } elseif ($RemoteFile -like "*:*" -and $RemoteFile -notlike "\\*") {
                    # Convert local path like C:\Scripts\file.ps1 to \\RemoteHost\C$\Scripts\file.ps1
                    $drive = $RemoteFile.Substring(0, 1)
                    $pathWithoutDrive = $RemoteFile.Substring(3)
                    $uncPath = "\\$RemoteHost\$drive`$\$pathWithoutDrive"
                    Write-Host "Converted local path to UNC: $uncPath"
                } else {
                    Write-Host "Using provided UNC path: $uncPath"
                }
                
                Write-Host "Executing remote file via UNC path: $uncPath"
                
                # Build parameter hashtable for remote script
                $remoteParams = @{}
                
                # Add all additional parameters
                foreach ($key in $AdditionalParams.Keys) {
                    $remoteParams[$key] = $AdditionalParams[$key]
                }
                
                # Execute remote script file with parameters using UNC path
                if ($remoteParams.Count -gt 0) {
                    Write-Host "Executing command: Invoke-Command -Session [RemoteSession] -FilePath '$uncPath' -ArgumentList [Parameters]"
                    Write-Host "Parameters being passed: $($remoteParams.Keys -join ', ')"
                    $result = Invoke-Command -Session $session -FilePath $uncPath -ArgumentList $remoteParams
                } else {
                    Write-Host "Executing command: Invoke-Command -Session [RemoteSession] -FilePath '$uncPath'"
                    Write-Host "No parameters being passed"
                    $result = Invoke-Command -Session $session -FilePath $uncPath
                }
                
            } else {
                Write-Host "Executing inline script block on remote host"
                Write-Host "Executing command: Invoke-Command -Session [RemoteSession] -ScriptBlock [InlineScript] -ArgumentList [Parameters]"
                Write-Host "Parameters being passed: $($AdditionalParams.Keys -join ', ')"
                
                # Execute inline script block
                $result = Invoke-Command -Session $session -ScriptBlock {
                    param($additionalParams)
                    
                    Write-Host "=== Remote Script Execution ==="
                    Write-Host "Executed on: $env:COMPUTERNAME"
                    Write-Host "Current User: $env:USERNAME"
                    
                    # Display all parameters
                    if ($additionalParams.Count -gt 0) {
                        Write-Host "Parameters:"
                        foreach ($key in $additionalParams.Keys) {
                            Write-Host "  $key = $($additionalParams[$key])"
                        }
                    }
                    
                    # Return execution details
                    return @{
                        Status = "Success"
                        ComputerName = $env:COMPUTERNAME
                        User = $env:USERNAME
                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        Parameters = $additionalParams
                    }
                } -ArgumentList $AdditionalParams
            }
            
            Write-Host "Remote execution completed successfully"
            return $result
            
        } catch {
            Write-Error "Failed to execute on remote host: $($_.Exception.Message)"
            throw $_
        } finally {
            if ($session) {
                Remove-PSSession $session -ErrorAction SilentlyContinue
                Write-Host "Remote session cleaned up"
            }
        }
        
    } else {
        Write-Host "=== Local Execution ==="
        Write-Host "Executing command: Local script execution (no Invoke-Command required)"
        Write-Host "Executed on: $env:COMPUTERNAME"
        Write-Host "Current User: $env:USERNAME"
        
        # Display all parameters
        if ($AdditionalParams.Count -gt 0) {
            Write-Host "Parameters:"
            foreach ($key in $AdditionalParams.Keys) {
                Write-Host "  $key = $($AdditionalParams[$key])"
            }
        } else {
            Write-Host "No parameters passed"
        }
        
        # Return execution details
        return @{
            Status = "Success"
            ComputerName = $env:COMPUTERNAME
            User = $env:USERNAME
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Parameters = $AdditionalParams
        }
    }
}

# Collect all additional parameters (exclude known parameters)
$knownParams = @('RemoteHost', 'RemoteUser', 'RemotePassword', 'RemoteFile')
$additionalParams = @{}

# Get all script parameters
foreach ($param in $PSBoundParameters.GetEnumerator()) {
    if ($param.Key -notin $knownParams) {
        $additionalParams[$param.Key] = $param.Value
    }
}

# Execute the command
try {
    $result = Execute-PowerShellCommand -RemoteHost $RemoteHost -RemoteUser $RemoteUser -RemotePassword $RemotePassword -RemoteFile $RemoteFile -AdditionalParams $additionalParams
    
    if ($result) {
        Write-Host "Execution Result:"
        Write-Host "  Status: $($result.Status)"
        Write-Host "  Computer: $($result.ComputerName)"
        Write-Host "  User: $($result.User)"
        Write-Host "  Timestamp: $($result.Timestamp)"
    }
    
    Write-Host "Script execution completed successfully"
    
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}