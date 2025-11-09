# Jenkins Shared Library - SCM Loading Examples

This document provides examples of different ways to load the Common-Library using SCM-based loading instead of pre-configured global libraries.

## Basic SCM Loading

### GitHub Public Repository
```groovy
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])
```

### GitHub Private Repository (with credentials)
```groovy
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git',
    credentialsId: 'github-pat-credentials'
])
```

### Specific Branch/Tag/Commit
```groovy
// Load from develop branch
library identifier: 'Common-Library@develop', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

// Load from specific tag
library identifier: 'Common-Library@v1.2.3', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

// Load from specific commit
library identifier: 'Common-Library@abc123def456', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])
```

## Alternative SCM Providers

### Azure DevOps
```groovy
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://dev.azure.com/organization/project/_git/Common-Library',
    credentialsId: 'azure-devops-credentials'
])
```

### GitLab
```groovy
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://gitlab.com/username/Common-Library.git',
    credentialsId: 'gitlab-credentials'
])
```

### Bitbucket
```groovy
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://bitbucket.org/username/common-library.git',
    credentialsId: 'bitbucket-credentials'
])
```

## Advanced SCM Options

### With Shallow Clone
```groovy
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git',
    traits: [gitBranchDiscovery(), [$class: 'CloneOptionTrait', shallow: true, depth: 1]]
])
```

### Multiple Libraries
```groovy
// Load multiple versions or libraries
library identifier: 'Common-Library@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Common-Library.git'
])

library identifier: 'Utils-Library@v2.0.0', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: 'https://github.com/singhmanupratap/Utils-Library.git'
])
```

### Dynamic Loading in Pipeline
```groovy
pipeline {
    agent any
    parameters {
        string(name: 'LIBRARY_VERSION', defaultValue: 'main', description: 'Library version to use')
    }
    stages {
        stage('Load Library') {
            steps {
                script {
                    library identifier: "Common-Library@${params.LIBRARY_VERSION}", retriever: modernSCM([
                        $class: 'GitSCMSource',
                        remote: 'https://github.com/singhmanupratap/Common-Library.git'
                    ])
                }
            }
        }
        stage('Use Library') {
            steps {
                script {
                    runpowerShell([
                        Date: '2025-11-09',
                        UserName: 'dynamic-user'
                    ])
                }
            }
        }
    }
}
```

## Benefits of SCM Loading

✅ **Version Control** - Load specific versions/branches/commits  
✅ **No Global Configuration** - No need to configure libraries globally in Jenkins  
✅ **Flexibility** - Different pipelines can use different library versions  
✅ **Testing** - Easy to test library changes on feature branches  
✅ **Security** - Can use different credentials for different repositories  
✅ **Multi-Source** - Load libraries from different SCM providers  

## Considerations

⚠️ **Performance** - SCM loading adds clone time to pipeline execution  
⚠️ **Network** - Requires network access to SCM during pipeline execution  
⚠️ **Credentials** - Need appropriate credentials for private repositories  
⚠️ **Caching** - Jenkins may cache libraries, affecting immediate updates  

## Recommended Approach

For production pipelines:
1. Use specific tags/commits instead of branches for stability
2. Store credentials securely in Jenkins credential store
3. Consider using shallow clones for better performance
4. Document library versions used in pipeline logs