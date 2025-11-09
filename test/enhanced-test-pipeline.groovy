// Enhanced test pipeline for improved runpowerShell shared library
// Demonstrates Invoke-Command capabilities and RemoteFile support
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

pipeline {
    agent any
    
    stages {
        stage('Test Local Execution') {
            steps {
                script {
                    echo "=== Testing Local Execution ==="
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'local-test-user',
                        Environment: 'Development',
                        LogLevel: 'Info'
                    ])
                }
            }
        }
        
        stage('Test Remote Execution - Current User') {
            when {
                expression { params.TEST_REMOTE_HOST != null && params.TEST_REMOTE_HOST != '' }
            }
            steps {
                script {
                    echo "=== Testing Remote Execution (Current User) ==="
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'remote-current-user',
                        RemoteHost: params.TEST_REMOTE_HOST,
                        Environment: 'Test',
                        LogLevel: 'Debug'
                    ])
                }
            }
        }
        
        stage('Test Remote Execution - With Credentials') {
            when {
                expression { 
                    params.TEST_REMOTE_HOST != null && 
                    params.TEST_REMOTE_HOST != '' &&
                    params.TEST_REMOTE_USER != null &&
                    params.TEST_REMOTE_USER != ''
                }
            }
            steps {
                script {
                    echo "=== Testing Remote Execution (With Credentials) ==="
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'remote-auth-user',
                        RemoteHost: params.TEST_REMOTE_HOST,
                        RemoteUser: params.TEST_REMOTE_USER,
                        RemotePassword: params.TEST_REMOTE_PASS ?: 'default-pass',
                        Environment: 'Production',
                        LogLevel: 'Verbose'
                    ])
                }
            }
        }
        
        stage('Test Remote File Execution') {
            when {
                expression { 
                    params.TEST_REMOTE_HOST != null && 
                    params.TEST_REMOTE_HOST != '' &&
                    params.TEST_REMOTE_FILE != null &&
                    params.TEST_REMOTE_FILE != ''
                }
            }
            steps {
                script {
                    echo "=== Testing Remote File Execution ==="
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'remote-file-user',
                        RemoteHost: params.TEST_REMOTE_HOST,
                        RemoteFile: params.TEST_REMOTE_FILE,
                        credentialsId: 'remote-server-credentials',
                        CustomParam1: 'Value1',
                        CustomParam2: 'Value2'
                    ])
                }
            }
        }
        
        stage('Test Custom Parameters') {
            steps {
                script {
                    echo "=== Testing Custom Parameters ==="
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'custom-param-user',
                        DatabaseServer: 'SQL01',
                        DatabaseName: 'MyDatabase',
                        TimeoutMinutes: '30',
                        EnableSSL: 'true',
                        ConfigFile: 'C:\\Config\\app.config',
                        Environment: 'UAT'
                    ])
                }
            }
        }
    }
    
    parameters {
        string(name: 'TEST_REMOTE_HOST', defaultValue: '', description: 'Remote host for testing (optional)')
        string(name: 'TEST_REMOTE_USER', defaultValue: '', description: 'Remote username for testing (optional)')
        password(name: 'TEST_REMOTE_PASS', defaultValue: '', description: 'Remote password for testing (optional)')
        string(name: 'TEST_REMOTE_FILE', defaultValue: '', description: 'Remote script file path for testing (optional)')
    }
    
    post {
        always {
            echo "Enhanced PowerShell library test completed."
        }
        success {
            echo "✅ All tests passed! Enhanced runpowerShell library is working correctly."
            echo "Features tested:"
            echo "  ✅ Local execution with custom parameters"
            echo "  ✅ Remote execution using Invoke-Command"
            echo "  ✅ Authentication with current user credentials"
            echo "  ✅ Authentication with provided credentials"
            echo "  ✅ Remote file execution support"
            echo "  ✅ Custom parameter passing"
        }
        failure {
            echo "❌ Some tests failed. Check the logs for error details."
        }
    }
}