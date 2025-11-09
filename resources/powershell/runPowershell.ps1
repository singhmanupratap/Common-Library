param(
    [Parameter(Mandatory=$true)]
    [string]$Date,
    
    [Parameter(Mandatory=$true)]
    [string]$UserName,
    
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
        [string]$Date,
        [string]$UserName,
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
                Write-Host "Executing remote file: $RemoteFile"
                
                # Build parameter hashtable for remote script
                $remoteParams = @{
                    Date = $Date
                    UserName = $UserName
                }
                
                # Add additional parameters
                foreach ($key in $AdditionalParams.Keys) {
                    $remoteParams[$key] = $AdditionalParams[$key]
                }
                
                # Execute remote script file with parameters
                $result = Invoke-Command -Session $session -FilePath $RemoteFile -ArgumentList $remoteParams
                
            } else {
                Write-Host "Executing inline script block on remote host"
                
                # Execute inline script block
                $result = Invoke-Command -Session $session -ScriptBlock {
                    param($d, $u, $additionalParams)
                    
                    Write-Host "=== Remote Script Execution ==="
                    Write-Host "Date: $d"
                    Write-Host "User Name: $u"
                    Write-Host "Executed on: $env:COMPUTERNAME"
                    Write-Host "Current User: $env:USERNAME"
                    
                    # Display additional parameters
                    if ($additionalParams.Count -gt 0) {
                        Write-Host "Additional Parameters:"
                        foreach ($key in $additionalParams.Keys) {
                            Write-Host "  $key = $($additionalParams[$key])"
                        }
                    }
                    
                    # Return execution details
                    return @{
                        Status = "Success"
                        ComputerName = $env:COMPUTERNAME
                        User = $env:USERNAME
                        Date = $d
                        UserName = $u
                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                } -ArgumentList $Date, $UserName, $AdditionalParams
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
        Write-Host "Date: $Date"
        Write-Host "User Name: $UserName"
        Write-Host "Executed on: $env:COMPUTERNAME"
        Write-Host "Current User: $env:USERNAME"
        
        # Display additional parameters
        if ($AdditionalParams.Count -gt 0) {
            Write-Host "Additional Parameters:"
            foreach ($key in $AdditionalParams.Keys) {
                Write-Host "  $key = $($AdditionalParams[$key])"
            }
        }
        
        # Return execution details
        return @{
            Status = "Success"
            ComputerName = $env:COMPUTERNAME
            User = $env:USERNAME
            Date = $Date
            UserName = $UserName
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
}

# Collect all additional parameters (exclude known parameters)
$knownParams = @('Date', 'UserName', 'RemoteHost', 'RemoteUser', 'RemotePassword', 'RemoteFile')
$additionalParams = @{}

# Get all script parameters
foreach ($param in $PSBoundParameters.GetEnumerator()) {
    if ($param.Key -notin $knownParams) {
        $additionalParams[$param.Key] = $param.Value
    }
}

# Execute the command
try {
    $result = Execute-PowerShellCommand -Date $Date -UserName $UserName -RemoteHost $RemoteHost -RemoteUser $RemoteUser -RemotePassword $RemotePassword -RemoteFile $RemoteFile -AdditionalParams $additionalParams
    
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