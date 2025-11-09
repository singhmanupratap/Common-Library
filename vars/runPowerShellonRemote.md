# runpowerShell - Enhanced Jenkins Shared Library

A Jenkins shared library function for executing PowerShell scripts locally or remotely using `Invoke-Command` with advanced remote execution capabilities.

## Features

- ✅ **Local and Remote Execution** - Uses `Invoke-Command` for robust remote execution
- ✅ **Multiple Authentication Methods** - Current user or provided credentials
- ✅ **Remote Script File Support** - Execute script files on remote hosts via `Invoke-Command -FilePath`
- ✅ **Jenkins Credentials Integration** - Secure credential handling
- ✅ **Custom Parameters** - Pass unlimited custom parameters to scripts
- ✅ **Cross-Platform Support** - Works on Windows and Unix agents
- ✅ **Enhanced Logging** - Detailed execution information with credential masking
- ✅ **Error Handling** - Comprehensive error reporting and session cleanup

## Usage

### Basic Local Execution

```groovy
@Library('Common-Library') _

pipeline {
    agent any
    stages {
        stage('Execute PowerShell') {
            steps {
                runpowerShell([
                    Date: '2025-11-09',
                    UserName: 'localuser'
                ])
            }
        }
    }
}
```

### Remote Execution with Current User Credentials

```groovy
runpowerShell([
    Date: '2025-11-09',
    UserName: 'remoteuser',
    RemoteHost: 'server.domain.com'
])
```

### Remote Execution with Provided Credentials

```groovy
runpowerShell([
    Date: '2025-11-09',
    UserName: 'remoteuser',
    RemoteHost: 'server.domain.com',
    RemoteUser: 'admin',
    RemotePassword: 'password123'
])
```

### Remote Execution with Jenkins Credentials

```groovy
runpowerShell([
    Date: '2025-11-09',
    UserName: 'remoteuser',
    RemoteHost: 'server.domain.com',
    credentialsId: 'remote-server-credentials'
])
```

### Remote Script File Execution

```groovy
runpowerShell([
    Date: '2025-11-09',
    UserName: 'remoteuser',
    RemoteHost: 'server.domain.com',
    RemoteFile: 'C:\\Scripts\\DeploymentScript.ps1',
    credentialsId: 'remote-server-credentials',
    Environment: 'Production',
    Version: '1.2.3',
    DatabaseServer: 'SQL01'
])
```

### Custom Parameters

```groovy
runpowerShell([
    Date: '2025-11-09',
    UserName: 'user',
    DatabaseServer: 'SQL01',
    DatabaseName: 'MyApp',
    TimeoutMinutes: '30',
    EnableSSL: 'true',
    ConfigFile: '/path/to/config.xml'
])
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `Date` | Yes | Date parameter for the PowerShell script |
| `UserName` | Yes | Username parameter for the PowerShell script |
| `fileName` | No | PowerShell script filename (default: 'runPowershell.ps1') |
| `RemoteHost` | No | Remote host for `Invoke-Command` execution |
| `RemoteUser` | No | Username for remote authentication |
| `RemotePassword` | No | Password for remote authentication |
| `RemoteFile` | No | Remote script file path for `Invoke-Command -FilePath` |
| `credentialsId` | No | Jenkins credentials ID for secure authentication |
| *Custom* | No | Any additional parameters are passed to the PowerShell script |

## Execution Modes

### 1. Local Execution
When no `RemoteHost` is specified, the script runs locally.

### 2. Remote Execution - Current User
When `RemoteHost` is specified without credentials, uses current user authentication.

### 3. Remote Execution - Provided Credentials
When `RemoteHost`, `RemoteUser`, and `RemotePassword` are provided.

### 4. Remote Execution - Jenkins Credentials
When `RemoteHost` and `credentialsId` are provided.

### 5. Remote File Execution
When `RemoteFile` is specified, uses `Invoke-Command -FilePath` to execute the remote script file.

## Technical Implementation

### PowerShell Script Features
- Uses `Invoke-Command` for all remote operations
- Supports both inline script blocks and remote file execution
- Automatic session management and cleanup
- Enhanced error handling and logging
- Support for unlimited custom parameters

### Groovy Library Features
- Parameter validation and sanitization
- Cross-platform file cleanup (Windows/Unix)
- Credential masking in logs
- Detailed execution mode detection
- Comprehensive error reporting

## Security Notes

- Use `credentialsId` parameter for production environments
- Passwords are automatically masked in Jenkins logs
- Remote sessions are automatically cleaned up
- Supports PowerShell execution policies and security settings
- Uses `PSSessionOption` for enhanced security

## Requirements

- Jenkins PowerShell plugin
- PowerShell 3.0+ on target systems
- For remote execution: PowerShell remoting enabled on target hosts
- For credential-based execution: Jenkins Credentials plugin
- Network connectivity to remote hosts (WinRM/PowerShell remoting ports)