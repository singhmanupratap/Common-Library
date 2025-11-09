// Test Pipeline for WinRM Configuration
// This pipeline tests the runPowerShellonRemote shared library

pipeline {
    agent any
    
    stages {
        stage('Test WinRM Setup') {
            steps {
                script {
                    // Test 1: Local execution (should work without WinRM)
                    echo "=== Test 1: Local Execution ==="
                    try {
                        runPowerShellonRemote(
                            RemoteHost: 'localhost',
                            RemoteFile: 'D:\\Users\\singh\\source\\repos\\JenkinsSetUp\\scripts\\sample.ps1',
                            Date: '2025-11-09',
                            UserName: 'jenkins'
                        )
                        echo "✓ Local execution test passed"
                    } catch (Exception e) {
                        echo "✗ Local execution test failed: ${e.message}"
                    }
                    
                    // Test 2: Remote execution with credentials (requires WinRM setup)
                    echo "\n=== Test 2: Remote Execution with Credentials ==="
                    try {
                        runPowerShellonRemote(
                            RemoteHost: '192.168.1.120',
                            RemoteUser: 'TestRemoteUser',
                            RemotePassword: 'TestPassword123',
                            RemoteFile: 'D:\\Users\\singh\\source\\repos\\JenkinsSetUp\\scripts\\sample.ps1',
                            Date: '2025-11-09',
                            UserName: 'jenkins'
                        )
                        echo "✓ Remote execution test passed"
                    } catch (Exception e) {
                        echo "✗ Remote execution test failed: ${e.message}"
                        echo "This is expected if WinRM is not properly configured"
                    }
                    
                    // Test 3: Simple connectivity test
                    echo "\n=== Test 3: Connectivity Test ==="
                    powershell '''
                        Write-Host "Testing connectivity to 192.168.1.120..."
                        $result = Test-NetConnection -ComputerName "192.168.1.120" -Port 5985 -InformationLevel Quiet
                        Write-Host "WinRM HTTP Port (5985): $(if($result) { 'Open' } else { 'Closed' })"
                        
                        try {
                            $wsmanTest = Test-WSMan -ComputerName "192.168.1.120" -ErrorAction Stop
                            Write-Host "WSMan Test: Success"
                            Write-Host "Remote PowerShell Version: $($wsmanTest.ProductVersion)"
                        } catch {
                            Write-Host "WSMan Test: Failed - $($_.Exception.Message)"
                        }
                    '''
                }
            }
        }
        
        stage('WinRM Configuration Check') {
            steps {
                script {
                    echo "=== WinRM Configuration Status ==="
                    powershell '''
                        Write-Host "Current WinRM Configuration:"
                        Write-Host ""
                        
                        # Check WinRM service
                        $winrmService = Get-Service WinRM
                        Write-Host "WinRM Service: $($winrmService.Status)"
                        
                        # Check TrustedHosts
                        try {
                            $trustedHosts = Get-Item WSMan:\\localhost\\Client\\TrustedHosts -ErrorAction SilentlyContinue
                            if ($trustedHosts) {
                                Write-Host "TrustedHosts: $($trustedHosts.Value)"
                            } else {
                                Write-Host "TrustedHosts: Not configured"
                            }
                        } catch {
                            Write-Host "TrustedHosts: Cannot read (may need admin rights)"
                        }
                        
                        # Check if current user is admin
                        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Write-Host "Running as Administrator: $isAdmin"
                        
                        Write-Host ""
                        Write-Host "To fix WinRM configuration, run as Administrator:"
                        Write-Host "1. Enable-PSRemoting -Force -SkipNetworkProfileCheck"
                        Write-Host "2. Set-Item WSMan:\\localhost\\Client\\TrustedHosts -Value '192.168.1.120' -Force"
                        Write-Host "3. Restart-Service WinRM"
                    '''
                }
            }
        }
    }
}