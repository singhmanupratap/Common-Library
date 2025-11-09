// Working test pipeline for runpowerShell shared library
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

pipeline {
    agent any
    
    stages {
        stage('Test Local PowerShell Execution') {
            steps {
                script {
                    echo "=== Testing Local PowerShell Execution ==="
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'jenkins-test-user'
                    ])
                }
            }
        }
        
        stage('Test PowerShell with Additional Parameters') {
            steps {
                script {
                    echo "=== Testing PowerShell with Custom Parameters ==="
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'jenkins-advanced-user',
                        Environment: 'Test',
                        LogLevel: 'Debug'
                    ])
                }
            }
        }
        
        stage('Test Different Script File') {
            steps {
                script {
                    echo "=== Testing Default PowerShell Script ==="
                    runpowerShell([
                        fileName: 'runPowershell.ps1',  // Explicit filename
                        Date: '2025-11-09',
                        UserName: 'explicit-file-test'
                    ])
                }
            }
        }
    }
    
    post {
        always {
            echo "Test pipeline completed. Check logs for PowerShell execution results."
        }
        success {
            echo "✅ All PowerShell tests passed successfully! Shared library is working perfectly."
        }
        failure {
            echo "❌ PowerShell tests failed. Check the logs for error details."
        }
    }
}