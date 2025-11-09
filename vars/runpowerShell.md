# runpowerShell - Jenkins Shared Library

A Jenkins shared library function for executing PowerShell scripts locally or remotely.

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

### Remote Execution with Direct Credentials

```groovy
runpowerShell([
    Date: '2025-11-09',
    UserName: 'remoteuser',
    RemoteHost: 'server.domain.com',
    RemoteUser: 'admin',
    RemotePassword: 'password123'
])
```

### Remote Execution with Jenkins Credentials (Recommended)

```groovy
runpowerShell([
    Date: '2025-11-09',
    UserName: 'remoteuser',
    RemoteHost: 'server.domain.com',
    credentialsId: 'remote-server-credentials'
])
```

### Custom PowerShell Script

```groovy
runpowerShell([
    fileName: 'custom-script.ps1',
    Date: '2025-11-09',
    UserName: 'user',
    CustomParam: 'value'
])
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `Date` | Yes | Date parameter for the PowerShell script |
| `UserName` | Yes | Username parameter for the PowerShell script |
| `fileName` | No | PowerShell script filename (default: 'runPowershell.ps1') |
| `RemoteHost` | No | Remote host for remote execution |
| `RemoteUser` | No | Username for remote authentication |
| `RemotePassword` | No | Password for remote authentication |
| `credentialsId` | No | Jenkins credentials ID for secure authentication |

## Features

- ✅ **Single Entry Point** - One `call()` method handles all execution modes
- ✅ **Automatic Credential Detection** - Automatically uses Jenkins credentials when `credentialsId` is provided
- ✅ **Local and Remote Execution** - Automatically detects execution mode
- ✅ **Parameter Validation** - Validates required parameters
- ✅ **Error Handling** - Comprehensive error reporting
- ✅ **Logging** - Detailed execution logging with credential masking
- ✅ **Flexible** - Supports custom PowerShell scripts and parameters

## Execution Flow

1. **Parameter Validation** - Checks required parameters (`Date`, `UserName`)
2. **Credential Detection** - If `credentialsId` is provided, uses Jenkins credentials
3. **Execution Mode** - Determines local vs remote execution based on parameters
4. **Script Loading** - Loads PowerShell script from library resources
5. **Parameter Building** - Constructs PowerShell parameter string
6. **Execution** - Runs PowerShell script with appropriate parameters

## Methods

### `call(Map parameters)`
Main function for executing PowerShell scripts. Automatically handles credential resolution.

### `withCredentials(Map parameters, String credentialsId)`
Internal method for handling Jenkins credential resolution.

### `executeScript(Map parameters)`
Core execution method (internal use).

## Requirements

- Jenkins PowerShell plugin
- For remote execution: PowerShell remoting enabled on target hosts
- For credential-based execution: Jenkins Credentials plugin

## Security Notes

- Use `credentialsId` parameter for production environments
- Avoid hardcoding passwords in pipeline scripts
- Credentials are automatically masked in logs
- Ensure PowerShell remoting is properly secured on target hosts