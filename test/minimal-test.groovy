// Minimal test for runpowerShell shared library
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

pipeline {
    agent any
    
    stages {
        stage('Quick Test') {
            steps {
                script {
                    echo "Testing runpowerShell shared library..."
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'quick-test-user'
                    ])
                    echo "Test completed successfully!"
                }
            }
        }
    }
}