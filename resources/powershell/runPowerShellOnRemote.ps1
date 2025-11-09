param(
    [Parameter(Mandatory=$false)]
    [string]$RemoteHost,
    
    [Parameter(Mandatory=$false)]
    [string]$RemoteUser,
    
    [Parameter(Mandatory=$false)]
    [string]$RemotePassword,
    
    [Parameter(Mandatory=$false)]
    [string]$RemoteFile,
    
    [Parameter(Mandatory=$false)]
    [hashtable]$AdditionalParams = @{}
)

# Function to convert local path to UNC path
function Convert-ToUNCPath {
    param(
        [string]$LocalPath,
        [string]$RemoteHost
    )
    
    # If already a UNC path, return as-is
    if ($LocalPath -like "\\*") {
        return $LocalPath
    }
    
    # Convert local path like C:\path\file.ps1 to \\RemoteHost\C$\path\file.ps1
    if ($LocalPath -match "^([A-Za-z]):(.*)") {
        $drive = $matches[1]
        $pathWithoutDrive = $matches[2]
        $uncPath = "\\$RemoteHost\$drive`$" + $pathWithoutDrive
        return $uncPath
    } else {
        # If no drive letter, assume it's a relative path and add to C$
        $uncPath = "\\$RemoteHost\C$\" + $LocalPath.TrimStart('\')
        return $uncPath
    }
}

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
    $isRemoteExecution = -not [string]::IsNullOrEmpty($RemoteHost) -and $RemoteHost -ne "localhost" -and $RemoteHost -ne $env:COMPUTERNAME -and $RemoteHost -ne "127.0.0.1"
    
    if ($isRemoteExecution) {
        Write-Host "=== Remote Execution on: $RemoteHost ==="
        
        # Pre-connection validation
        Write-Host "Performing pre-connection checks..."
        
        # Test basic connectivity
        try {
            $pingResult = Test-NetConnection -ComputerName $RemoteHost -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($pingResult) {
                Write-Host "✓ Basic connectivity to $RemoteHost successful"
            } else {
                Write-Host "⚠ Basic connectivity test failed - host may be unreachable"
            }
        } catch {
            Write-Host "⚠ Could not test connectivity: $($_.Exception.Message)"
        }
        
        # Test WinRM connectivity
        try {
            $winrmTest = Test-NetConnection -ComputerName $RemoteHost -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($winrmTest.TcpTestSucceeded) {
                Write-Host "✓ WinRM port 5985 is accessible"
            } else {
                Write-Host "⚠ WinRM port 5985 is not accessible - check firewall and WinRM configuration"
            }
        } catch {
            Write-Host "⚠ Could not test WinRM connectivity: $($_.Exception.Message)"
        }
        
        # Create session configuration
        $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck
        $session = $null
        
        # Configure WinRM trusted hosts if needed
        Write-Host "Checking WinRM configuration..."
        try {
            $currentTrustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
            if (-not $currentTrustedHosts -or $currentTrustedHosts.Value -notlike "*$RemoteHost*") {
                Write-Host "Adding $RemoteHost to TrustedHosts..."
                if ($currentTrustedHosts -and $currentTrustedHosts.Value) {
                    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$($currentTrustedHosts.Value),$RemoteHost" -Force
                } else {
                    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $RemoteHost -Force
                }
                Write-Host "TrustedHosts updated successfully"
            } else {
                Write-Host "$RemoteHost is already in TrustedHosts"
            }
            
            # Enable unencrypted traffic for basic authentication
            try {
                $allowUnencrypted = Get-Item WSMan:\localhost\Client\AllowUnencrypted -ErrorAction SilentlyContinue
                if (-not $allowUnencrypted -or $allowUnencrypted.Value -eq "false") {
                    Write-Host "Enabling unencrypted traffic for basic authentication..."
                    Set-Item WSMan:\localhost\Client\AllowUnencrypted -Value $true -Force
                    Write-Host "Unencrypted traffic enabled"
                }
            } catch {
                Write-Warning "Could not configure unencrypted traffic: $($_.Exception.Message)"
            }
        }
        catch {
            Write-Warning "Could not update TrustedHosts (may require admin rights): $($_.Exception.Message)"
            Write-Host "Attempting connection anyway..."
        }
        
        try {
            # Create session based on authentication method
            if (-not [string]::IsNullOrEmpty($RemoteUser) -and -not [string]::IsNullOrEmpty($RemotePassword)) {
                Write-Host "Using provided credentials for authentication"
                $securePassword = ConvertTo-SecureString $RemotePassword -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential($RemoteUser, $securePassword)
                
                Write-Host "Attempting to connect to: $RemoteHost"
                Write-Host "Connecting as user: $RemoteUser"
                
                try {
                    $session = New-PSSession -ComputerName $RemoteHost -Credential $credential -SessionOption $sessionOptions -ErrorAction Stop
                    Write-Host "Successfully connected with provided credentials"
                }
                catch {
                    Write-Host "Failed with default authentication: $($_.Exception.Message)"
                    Write-Host "Trying with basic authentication..."
                    try {
                        $session = New-PSSession -ComputerName $RemoteHost -Credential $credential -Authentication Basic -ErrorAction Stop
                        Write-Host "Successfully connected with basic authentication"
                    }
                    catch {
                        Write-Host "Failed with basic authentication: $($_.Exception.Message)"
                        Write-Host "Trying with NTLM authentication..."
                        try {
                            $session = New-PSSession -ComputerName $RemoteHost -Credential $credential -Authentication Negotiate -ErrorAction Stop
                            Write-Host "Successfully connected with NTLM authentication"
                        }
                        catch {
                            Write-Host "All authentication methods failed: $($_.Exception.Message)"
                            $session = $null
                        }
                    }
                }
            } else {
                Write-Host "Using current user credentials for authentication"
                Write-Host "Attempting to connect to: $RemoteHost"
                Write-Host "Connecting as current user: $env:USERNAME"
                try {
                    $session = New-PSSession -ComputerName $RemoteHost -SessionOption $sessionOptions -ErrorAction Stop
                    Write-Host "Successfully connected to remote host: $RemoteHost"
                } catch {
                    Write-Host "Failed to connect with current user credentials: $($_.Exception.Message)"
                    $session = $null
                }
            }
            
            # Check if session was created successfully
            if (-not $session) {
                Write-Host ""
                Write-Host "=== Remote Connection Failed - Attempting UNC Path Execution ===" -ForegroundColor Yellow
                Write-Host "Since remote session creation failed, trying direct UNC path access..."
                
                if (-not [string]::IsNullOrEmpty($RemoteFile)) {
                    # Try UNC path execution as fallback
                    $uncPath = Convert-ToUNCPath -LocalPath $RemoteFile -RemoteHost $RemoteHost
                    Write-Host "Attempting direct UNC execution: $uncPath"
                    
                    if (Test-Path $uncPath) {
                        Write-Host "UNC path accessible - executing directly"
                        
                        # Build parameter string for direct execution
                        $paramString = ""
                        if ($AdditionalParams.Count -gt 0) {
                            foreach ($key in $AdditionalParams.Keys) {
                                $value = $AdditionalParams[$key]
                                $paramString += " -$key '$value'"
                            }
                        }
                        
                        $command = "& '$uncPath'$paramString"
                        Write-Host "Executing: $command"
                        
                        try {
                            $result = Invoke-Expression $command
                            Write-Host "UNC path execution completed successfully"
                            return @{
                                Status = "Success (UNC)"
                                ComputerName = $RemoteHost
                                Method = "UNC Path Direct Execution"
                                Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                                Parameters = $AdditionalParams
                            }
                        }
                        catch {
                            Write-Warning "UNC path execution failed: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Warning "UNC path not accessible: $uncPath"
                    }
                }
                
                # If we reach here, all methods failed
                throw "Unable to establish remote connection or access via UNC path to $RemoteHost"
            }
            
            Write-Host "Successfully connected to remote host: $RemoteHost"
            
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
                    
                    # Build script block that calls the remote file with parameters
                    $scriptBlock = {
                        param($filePath, $parameters)
                        
                        # Build parameter string for the remote script
                        $paramString = ""
                        foreach ($key in $parameters.Keys) {
                            $value = $parameters[$key]
                            $paramString += " -$key '$value'"
                        }
                        
                        # Execute the remote script with parameters
                        $command = "& '$filePath'$paramString"
                        Write-Host "Executing: $command"
                        Invoke-Expression $command
                    }
                    
                    $result = Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $uncPath, $remoteParams
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
            Write-Host "=== Remote Connection Failed ==="
            Write-Host "Remote Host: $RemoteHost"
            Write-Host "Error: $($_.Exception.Message)"
            
            # Check if this is localhost and we can fall back to local execution
            $isLocalhost = $RemoteHost -in @("localhost", "127.0.0.1", $env:COMPUTERNAME)
            
            if ($isLocalhost) {
                Write-Host ""
                Write-Host "=== Falling Back to Local Execution ==="
                Write-Host "Since RemoteHost is localhost and remote connection failed, switching to local execution..."
                
                # Execute the remote file locally
                if (-not [string]::IsNullOrEmpty($RemoteFile)) {
                    Write-Host "Executing local file: $RemoteFile"
                    
                    # Display all parameters
                    if ($AdditionalParams.Count -gt 0) {
                        Write-Host "Parameters:"
                        foreach ($key in $AdditionalParams.Keys) {
                            Write-Host "  $key = $($AdditionalParams[$key])"
                        }
                        
                        # Build parameter string for the local script
                        $paramString = ""
                        foreach ($key in $AdditionalParams.Keys) {
                            $value = $AdditionalParams[$key]
                            $paramString += " -$key '$value'"
                        }
                        
                        # Execute the local script with parameters
                        $command = "& '$RemoteFile'$paramString"
                        Write-Host "Executing locally: $command"
                        try {
                            $result = Invoke-Expression $command
                            Write-Host "Local execution completed successfully"
                            return $result
                        } catch {
                            Write-Error "Failed to execute local script: $($_.Exception.Message)"
                            throw $_
                        }
                    } else {
                        Write-Host "No parameters passed"
                        # Execute the local script without parameters
                        $command = "& '$RemoteFile'"
                        Write-Host "Executing locally: $command"
                        try {
                            $result = Invoke-Expression $command
                            Write-Host "Local execution completed successfully"
                            return $result
                        } catch {
                            Write-Error "Failed to execute local script: $($_.Exception.Message)"
                            throw $_
                        }
                    }
                } else {
                    # Return basic execution details for inline execution
                    return @{
                        Status = "Success"
                        ComputerName = $env:COMPUTERNAME
                        User = $env:USERNAME
                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        Parameters = $AdditionalParams
                        ExecutionMode = "Local (fallback)"
                    }
                }
            } else {
                # Provide troubleshooting information for real remote hosts
                Write-Host ""
                Write-Host "=== Troubleshooting Information ==="
                Write-Host "1. Ensure WinRM is enabled on the remote host:"
                Write-Host "   - Run: winrm quickconfig"
                Write-Host "   - Run: Enable-PSRemoting -Force"
                Write-Host ""
                Write-Host "2. Check network connectivity:"
                Write-Host "   - Test-NetConnection -ComputerName $RemoteHost -Port 5985"
                Write-Host "   - Test-NetConnection -ComputerName $RemoteHost -Port 5986"
                Write-Host ""
                Write-Host "3. Verify authentication:"
                Write-Host "   - Ensure credentials are correct"
                Write-Host "   - Check if remote user has 'Log on as a service' rights"
                Write-Host "   - Consider using domain credentials: domain\\username"
                Write-Host ""
                Write-Host "4. Firewall settings:"
                Write-Host "   - Ensure Windows Remote Management ports are open"
                Write-Host "   - Default HTTP: 5985, HTTPS: 5986"
                Write-Host ""
                
                throw "Failed to establish remote PowerShell session to $RemoteHost`: $($_.Exception.Message)"
            }
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
        
        # Execute the remote file locally if specified
        if (-not [string]::IsNullOrEmpty($RemoteFile)) {
            Write-Host "Executing local file: $RemoteFile"
            
            # Display all parameters
            if ($AdditionalParams.Count -gt 0) {
                Write-Host "Parameters:"
                foreach ($key in $AdditionalParams.Keys) {
                    Write-Host "  $key = $($AdditionalParams[$key])"
                }
                
                # Build parameter string for the local script
                $paramString = ""
                foreach ($key in $AdditionalParams.Keys) {
                    $value = $AdditionalParams[$key]
                    $paramString += " -$key '$value'"
                }
                
                # Execute the local script with parameters
                $command = "& '$RemoteFile'$paramString"
                Write-Host "Executing: $command"
                try {
                    $result = Invoke-Expression $command
                } catch {
                    Write-Error "Failed to execute local script: $($_.Exception.Message)"
                    throw $_
                }
            } else {
                Write-Host "No parameters passed"
                # Execute the local script without parameters
                $command = "& '$RemoteFile'"
                Write-Host "Executing: $command"
                try {
                    $result = Invoke-Expression $command
                } catch {
                    Write-Error "Failed to execute local script: $($_.Exception.Message)"
                    throw $_
                }
            }
        } else {
            # Display all parameters
            if ($AdditionalParams.Count -gt 0) {
                Write-Host "Parameters:"
                foreach ($key in $AdditionalParams.Keys) {
                    Write-Host "  $key = $($AdditionalParams[$key])"
                }
            } else {
                Write-Host "No parameters passed"
            }
            
            # Return execution details for inline execution
            $result = @{
                Status = "Success"
                ComputerName = $env:COMPUTERNAME
                User = $env:USERNAME
                Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Parameters = $AdditionalParams
            }
        }
        
        return $result
    }
}

# Execute the command
try {
    $result = Execute-PowerShellCommand -RemoteHost $RemoteHost -RemoteUser $RemoteUser -RemotePassword $RemotePassword -RemoteFile $RemoteFile -AdditionalParams $AdditionalParams
    
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