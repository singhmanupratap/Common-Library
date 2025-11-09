// Comprehensive test pipeline for runPowerShellOnRemote shared library
// Tests remote PowerShell execution with UNC path generation and various authentication methods
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

pipeline {
    agent any
    
    parameters {
        string(name: 'REMOTE_HOST', defaultValue: 'server.domain.com', description: 'Remote host for PowerShell execution')
        string(name: 'REMOTE_USER', defaultValue: 'admin', description: 'Remote username')
        password(name: 'REMOTE_PASSWORD', defaultValue: '', description: 'Remote password')
        string(name: 'REMOTE_FILE', defaultValue: 'Scripts\\TestScript.ps1', description: 'Remote PowerShell file path')
        choice(name: 'AUTH_METHOD', choices: ['Direct', 'Jenkins'], description: 'Authentication method')
        string(name: 'REMOTE_CREDENTIALS_ID', defaultValue: 'remote-server-creds', description: 'Jenkins credentials ID')
    }
    
    stages {
        stage('Test Remote Execution - Direct Credentials') {
            when {
                expression { params.AUTH_METHOD == 'Direct' }
            }
            steps {
                script {
                    echo "=== Testing Remote PowerShell with Direct Credentials ==="
                    echo "Remote Host: ${params.REMOTE_HOST}"
                    echo "Remote File: ${params.REMOTE_FILE}"
                    
                    runPowerShellonRemote([
                        RemoteHost: params.REMOTE_HOST,
                        RemoteUser: params.REMOTE_USER,
                        RemotePassword: params.REMOTE_PASSWORD,
                        RemoteFile: params.REMOTE_FILE,
                        Environment: 'Test',
                        LogLevel: 'Debug',
                        BuildNumber: env.BUILD_NUMBER,
                        JobName: env.JOB_NAME
                    ])
                }
            }
        }
        
        stage('Test Remote Execution - Jenkins Credentials') {
            when {
                expression { params.AUTH_METHOD == 'Jenkins' }
            }
            steps {
                script {
                    echo "=== Testing Remote PowerShell with Jenkins Credentials ==="
                    echo "Remote Host: ${params.REMOTE_HOST}"
                    echo "Remote File: ${params.REMOTE_FILE}"
                    echo "Credentials ID: ${params.REMOTE_CREDENTIALS_ID}"
                    
                    runPowerShellonRemote([
                        RemoteHost: params.REMOTE_HOST,
                        RemoteFile: params.REMOTE_FILE,
                        RemoteCredentialsId: params.REMOTE_CREDENTIALS_ID,
                        Environment: 'Production',
                        LogLevel: 'Info',
                        BuildNumber: env.BUILD_NUMBER,
                        JobName: env.JOB_NAME,
                        Branch: env.BRANCH_NAME ?: 'main'
                    ])
                }
            }
        }
        
        stage('Test Different Path Formats') {
            steps {
                script {
                    echo "=== Testing Different Remote File Path Formats ==="
                    
                    def testPaths = [
                        'Scripts\\RelativeTest.ps1',           // Relative path
                        'C:\\Scripts\\AbsoluteTest.ps1',       // Absolute path
                        'D:\\Apps\\Scripts\\DriveTest.ps1',    // Different drive
                        "\\\\${params.REMOTE_HOST}\\C\$\\Scripts\\UNCTest.ps1"  // UNC path
                    ]
                    
                    testPaths.each { testPath ->
                        echo "Testing path format: ${testPath}"
                        try {
                            runPowerShellonRemote([
                                RemoteHost: params.REMOTE_HOST,
                                RemoteUser: params.REMOTE_USER,
                                RemotePassword: params.REMOTE_PASSWORD,
                                RemoteFile: testPath,
                                TestPath: testPath,
                                TestType: 'PathFormatValidation'
                            ])
                        } catch (Exception e) {
                            echo "Path test failed for ${testPath}: ${e.getMessage()}"
                            // Continue with other tests
                        }
                    }
                }
            }
        }
        
        stage('Test Custom Parameters') {
            steps {
                script {
                    echo "=== Testing Custom Parameter Passing ==="
                    
                    runPowerShellonRemote([
                        RemoteHost: params.REMOTE_HOST,
                        RemoteUser: params.REMOTE_USER,
                        RemotePassword: params.REMOTE_PASSWORD,
                        RemoteFile: params.REMOTE_FILE,
                        
                        // Custom application parameters
                        ApplicationName: 'TestApp',
                        DatabaseServer: 'db.domain.com',
                        ConfigPath: 'C:\\Config\\app.config',
                        ServicePort: '8080',
                        EnableLogging: 'true',
                        MaxRetries: '3',
                        TimeoutSeconds: '30'
                    ])
                }
            }
        }
    }
    
    post {
        always {
            echo "=== Test Pipeline Completed ==="
            echo "All remote PowerShell execution tests have been completed"
        }
        failure {
            echo "=== Test Pipeline Failed ==="
            echo "Some tests failed. Please check the logs for details."
        }
        success {
            echo "=== Test Pipeline Succeeded ==="
            echo "All tests passed successfully!"
        }
    }
}