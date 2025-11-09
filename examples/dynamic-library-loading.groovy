// Example Jenkins Pipeline showing different library loading methods
// Method 1: Load from specific branch/tag
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

// Method 2: Load from specific commit
// library identifier: 'Common-Library@abc123def', retriever: modernSCM([
//     $class: 'GitSCMSource',
//     remote: 'https://github.com/singhmanupratap/Common-Library.git'
// ])

// Method 3: Load with credentials for private repo
// library identifier: 'Common-Library@main', retriever: modernSCM([
//     $class: 'GitSCMSource',
//     remote: 'https://github.com/singhmanupratap/Common-Library.git',
//     credentialsId: 'github-credentials'
// ])

// Method 4: Load from different SCM (e.g., Azure DevOps)
// library identifier: 'Common-Library@main', retriever: modernSCM([
//     $class: 'GitSCMSource',
//     remote: 'https://dev.azure.com/organization/project/_git/Common-Library'
// ])

pipeline {
    agent any
    
    parameters {
        string(name: 'LIBRARY_VERSION', defaultValue: 'main', description: 'Library branch/tag to use')
        string(name: 'TARGET_DATE', defaultValue: '2025-11-09', description: 'Date parameter')
        string(name: 'TARGET_USER', defaultValue: 'jenkins', description: 'Username parameter')
        string(name: 'REMOTE_HOST', defaultValue: '', description: 'Remote host (optional)')
    }
    
    stages {
        stage('Dynamic Library Loading') {
            steps {
                script {
                    // Example of loading library dynamically based on parameter
                    if (params.LIBRARY_VERSION != 'main') {
                        library identifier: "Common-Library@${params.LIBRARY_VERSION}", retriever: modernSCM([
                            $class: 'GitSCMSource',
                            remote: 'https://github.com/singhmanupratap/Common-Library.git'
                        ])
                    }
                    
                    echo "Using Common-Library version: ${params.LIBRARY_VERSION}"
                }
            }
        }
        
        stage('Execute PowerShell') {
            steps {
                script {
                    echo "=== PowerShell Execution with Dynamic Library ==="
                    runpowerShell([
                        Date: params.TARGET_DATE,
                        UserName: params.TARGET_USER,
                        RemoteHost: params.REMOTE_HOST,
                        LibraryVersion: params.LIBRARY_VERSION
                    ])
                }
            }
        }
        
        stage('Test Different Configurations') {
            parallel {
                stage('Local Test') {
                    steps {
                        script {
                            runpowerShell([
                                Date: params.TARGET_DATE,
                                UserName: 'local-test-user',
                                TestMode: 'true'
                            ])
                        }
                    }
                }
                
                stage('Remote Test') {
                    when {
                        expression { params.REMOTE_HOST != '' }
                    }
                    steps {
                        script {
                            runpowerShell([
                                Date: params.TARGET_DATE,
                                UserName: 'remote-test-user',
                                RemoteHost: params.REMOTE_HOST,
                                credentialsId: 'remote-test-credentials',
                                TestMode: 'true'
                            ])
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully with library version: ${params.LIBRARY_VERSION}"
        }
        failure {
            echo "Pipeline failed. Library version used: ${params.LIBRARY_VERSION}"
        }
    }
}