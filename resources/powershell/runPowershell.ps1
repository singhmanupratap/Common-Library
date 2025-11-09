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
    [string]$RemotePassword
)

# Function to execute commands locally or remotely
function Execute-Command {
    param(
        [string]$Command,
        [string]$HostName,
        [string]$User,
        [string]$Password
    )
    
    if ($HostName -and $User -and $Password) {
        Write-Host "Executing on remote host: $HostName"
        
        # Create credential object
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($User, $SecurePassword)
        
        # Execute command on remote host
        try {
            $session = New-PSSession -ComputerName $HostName -Credential $Credential
            $result = Invoke-Command -Session $session -ScriptBlock {
                param($d, $u)
                Write-Host "Date: $d"
                Write-Host "User Name: $u"
                Write-Host "Executed on: $env:COMPUTERNAME"
            } -ArgumentList $Date, $UserName
            
            Remove-PSSession $session
            return $result
        }
        catch {
            Write-Error "Failed to execute on remote host: $($_.Exception.Message)"
            return $false
        }
    }
    else {
        Write-Host "Executing locally"
        Write-Host "Date: $Date"
        Write-Host "User Name: $UserName"
        Write-Host "Executed on: $env:COMPUTERNAME"
    }
}

# Execute the command
Execute-Command -Command "SampleCommand" -HostName $RemoteHost -User $RemoteUser -Password $RemotePassword