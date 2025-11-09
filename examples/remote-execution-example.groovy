// Example Jenkins Pipeline using runpowerShell shared library
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_DATE', defaultValue: '2025-11-09', description: 'Date parameter for PowerShell script')
        string(name: 'TARGET_USER', defaultValue: 'jenkins', description: 'Username parameter for PowerShell script')
        string(name: 'REMOTE_HOST', defaultValue: '', description: 'Remote host (leave empty for local execution)')
        choice(name: 'EXECUTION_MODE', choices: ['local', 'remote-direct', 'remote-credentials'], description: 'Execution mode')
    }
    
    stages {
        stage('Local Execution') {
            when {
                expression { params.EXECUTION_MODE == 'local' }
            }
            steps {
                script {
                    echo "=== Local PowerShell Execution ==="
                    runpowerShell([
                        Date: params.TARGET_DATE,
                        UserName: params.TARGET_USER
                    ])
                }
            }
        }
        
        stage('Remote Execution - Direct Credentials') {
            when {
                expression { params.EXECUTION_MODE == 'remote-direct' }
            }
            steps {
                script {
                    echo "=== Remote PowerShell Execution (Direct Credentials) ==="
                    // Note: This is for demonstration only - use credentialsId in production
                    runpowerShell([
                        Date: params.TARGET_DATE,
                        UserName: params.TARGET_USER,
                        RemoteHost: params.REMOTE_HOST,
                        RemoteUser: 'admin',
                        RemotePassword: 'demo-password'  // Don't do this in production!
                    ])
                }
            }
        }
        
        stage('Remote Execution - Jenkins Credentials') {
            when {
                expression { params.EXECUTION_MODE == 'remote-credentials' }
            }
            steps {
                script {
                    echo "=== Remote PowerShell Execution (Jenkins Credentials) ==="
                    // Clean single-call approach with credentials
                    runpowerShell([
                        Date: params.TARGET_DATE,
                        UserName: params.TARGET_USER,
                        RemoteHost: params.REMOTE_HOST,
                        credentialsId: 'remote-server-credentials'  // Jenkins credential ID
                    ])
                }
            }
        }
        
        stage('Custom Script with Credentials') {
            steps {
                script {
                    echo "=== Custom PowerShell Script with Credentials ==="
                    runpowerShell([
                        fileName: 'custom-script.ps1',  // If you have other PS scripts
                        Date: params.TARGET_DATE,
                        UserName: params.TARGET_USER,
                        RemoteHost: params.REMOTE_HOST,
                        credentialsId: 'remote-server-credentials',
                        CustomParameter: 'Additional Value'
                    ])
                }
            }
        }
        
        stage('Multiple Parameter Examples') {
            steps {
                script {
                    echo "=== Multiple Custom Parameters ==="
                    runpowerShell([
                        Date: params.TARGET_DATE,
                        UserName: params.TARGET_USER,
                        Environment: 'Production',
                        LogLevel: 'Info',
                        Timeout: '300',
                        EnableVerbose: 'true'
                    ])
                }
            }
        }
    }
    
    post {
        success {
            echo "PowerShell execution completed successfully!"
        }
        failure {
            echo "PowerShell execution failed. Check the logs for details."
        }
        always {
            echo "Pipeline execution finished."
        }
    }
}