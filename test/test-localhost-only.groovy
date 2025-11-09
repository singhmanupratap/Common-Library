// Quick Test Pipeline - Localhost Only
// This tests the core functionality without remote connection issues

pipeline {
    agent any
    
    stages {
        stage('Test Core Functionality') {
            steps {
                script {
                    echo "=== Testing Shared Library with Localhost ==="
                    
                    try {
                        // Test with localhost (should work without WinRM setup)
                        def result = runPowerShellonRemote(
                            RemoteHost: 'localhost',
                            RemoteFile: 'D:\\Users\\singh\\source\\repos\\JenkinsSetUp\\scripts\\sample.ps1',
                            Date: '2025-11-09',
                            UserName: 'jenkins-test'
                        )
                        
                        echo "✓ Localhost execution successful!"
                        echo "Result: ${result}"
                        
                    } catch (Exception e) {
                        echo "✗ Test failed: ${e.message}"
                        echo "This indicates an issue with the core library logic, not WinRM"
                        throw e
                    }
                }
            }
        }
        
        stage('Test Direct Script Execution') {
            steps {
                script {
                    echo "=== Testing Direct Script Execution ==="
                    
                    // Test the local execution helper script
                    powershell '''
                        $testParams = @{
                            Date = "2025-11-09"
                            UserName = "direct-test"
                        }
                        
                        & ".\\resources\\powershell\\Test-LocalExecution.ps1" -RemoteFile "D:\\Users\\singh\\source\\repos\\JenkinsSetUp\\scripts\\sample.ps1" -AdditionalParams $testParams
                    '''
                }
            }
        }
        
        stage('Verify Sample Script') {
            steps {
                script {
                    echo "=== Verifying Target Script Exists ==="
                    
                    powershell '''
                        $scriptPath = "D:\\Users\\singh\\source\\repos\\JenkinsSetUp\\scripts\\sample.ps1"
                        
                        if (Test-Path $scriptPath) {
                            Write-Host "✓ Target script found: $scriptPath" -ForegroundColor Green
                            Write-Host ""
                            Write-Host "Script content preview:"
                            Get-Content $scriptPath | Select-Object -First 10 | ForEach-Object { "  $_" }
                            Write-Host ""
                            Write-Host "Script size: $((Get-Item $scriptPath).Length) bytes"
                        } else {
                            Write-Warning "✗ Target script not found: $scriptPath"
                            Write-Host "Available scripts in JenkinsSetUp:"
                            if (Test-Path "D:\\Users\\singh\\source\\repos\\JenkinsSetUp\\scripts\\") {
                                Get-ChildItem "D:\\Users\\singh\\source\\repos\\JenkinsSetUp\\scripts\\*.ps1" | ForEach-Object { "  $($_.Name)" }
                            } else {
                                Write-Warning "JenkinsSetUp scripts directory not found"
                            }
                        }
                    '''
                }
            }
        }
    }
}