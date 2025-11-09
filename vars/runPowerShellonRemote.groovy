#!/usr/bin/env groovy

/**
 * Execute PowerShell scripts locally or remotely using Invoke-Command
 * 
 * @param parameters Map containing:
 *   - RemoteHost: Required remote host for remote execution via Invoke-Command
 *   - RemoteUser: Required remote username for authentication
 *   - RemotePassword: Required remote password for authentication
 *   - RemoteFile: Required remote script file path (will be converted to UNC path for remote execution)
 *   - RemoteCredentialsId: Optional Jenkins credentials ID for secure remote authentication
 *   - Any other custom parameters will be passed to the remote PowerShell script
 * 
 * Examples:
 *   // Remote execution with direct credentials (relative path)
 *   runpowerShell([
 *       RemoteHost: 'server.domain.com',
 *       RemoteUser: 'admin',
 *       RemotePassword: 'password123',
 *       RemoteFile: 'Scripts\\MyScript.ps1'  // Will become \\server.domain.com\C$\Scripts\MyScript.ps1
 *   ])
 *
 *   // Remote execution with absolute path
 *   runpowerShell([
 *       RemoteHost: 'server.domain.com',
 *       RemoteUser: 'admin',
 *       RemotePassword: 'password123',
 *       RemoteFile: 'C:\\Scripts\\MyScript.ps1'  // Will become \\server.domain.com\C$\Scripts\MyScript.ps1
 *   ])
 *
 *   // Remote execution with Jenkins credentials (UNC path)
 *   runpowerShell([
 *       RemoteHost: 'server.domain.com',
 *       RemoteFile: '\\\\server.domain.com\\C$\\Scripts\\MyScript.ps1',  // Already UNC format
 *       RemoteCredentialsId: 'remote-server-credentials'
 *   ])
 *
 *   // Remote execution with custom parameters
 *   runpowerShell([
 *       RemoteHost: 'server.domain.com',
 *       RemoteUser: 'admin',
 *       RemotePassword: 'password123',
 *       RemoteFile: 'D:\\Apps\\Scripts\\MyScript.ps1',  // Will become \\server.domain.com\D$\Apps\Scripts\MyScript.ps1
 *       Environment: 'Production',
 *       LogLevel: 'Debug',
 *       DatabaseServer: 'db.domain.com'
 *   ])
 */
def call(Map parameters = [:]) {
    // Validate required parameters
    if (!parameters.RemoteHost) {
        error("Parameter 'RemoteHost' is required")
    }
    if (!parameters.RemoteFile) {
        error("Parameter 'RemoteFile' is required")
    }
    
    // Check if Jenkins credentials should be used
    if (parameters.RemoteCredentialsId) {
        echo "Using Jenkins credentials for remote authentication"
        withCredentials(parameters, parameters.RemoteCredentialsId)
    } else {
        // Validate credentials if not using Jenkins credentials
        if (!parameters.RemoteUser) {
            error("Parameter 'RemoteUser' is required when not using RemoteCredentialsId")
        }
        if (!parameters.RemotePassword) {
            error("Parameter 'RemotePassword' is required when not using RemoteCredentialsId")
        }
        // Direct execution with provided credentials
        executeScript(parameters)
    }
}

/**
 * Execute PowerShell scripts with credential support from Jenkins
 * 
 * @param parameters Map containing script parameters
 * @param RemoteCredentialsId Jenkins credentials ID for remote authentication
 */
def withCredentials(Map parameters, String RemoteCredentialsId) {
    withCredentials([usernamePassword(
        credentialsId: RemoteCredentialsId,
        usernameVariable: 'REMOTE_USER',
        passwordVariable: 'REMOTE_PASS'
    )]) {
        // Add credentials to parameters
        def enhancedParams = parameters.clone()
        enhancedParams.RemoteUser = env.REMOTE_USER
        enhancedParams.RemotePassword = env.REMOTE_PASS
        
        // Remove RemoteCredentialsId from parameters to avoid passing it to PowerShell
        enhancedParams.remove('RemoteCredentialsId')
        
        // Call script execution function
        executeScript(enhancedParams)
    }
}

/**
 * Core function to execute PowerShell scripts
 * 
 * @param parameters Map containing script parameters (credentials resolved)
 */
def executeScript(Map parameters) {
    // Determine execution mode
    def hasCredentials = parameters.RemoteUser && parameters.RemotePassword
    
    try {
        // Load PowerShell script from resources
        def script = libraryResource "powershell/runPowerShellOnRemote.ps1"
        
        // Build parameter string for PowerShell
        def coreParams = ['RemoteHost', 'RemoteUser', 'RemotePassword', 'RemoteFile', 'RemoteCredentialsId']
        def additionalParams = [:]
        def coreParamString = ""
        def additionalParamString = ""
        
        parameters.each { key, value ->
            if (key in coreParams && key != 'RemoteCredentialsId') {
                // Core parameters for runPowerShellOnRemote.ps1
                def escapedValue = value.toString().replace("'", "''")
                coreParamString += " -${key} '${escapedValue}'"
            } else if (!(key in coreParams)) {
                // Additional parameters to be passed to the target script
                additionalParams[key] = value
            }
        }
        
        // Add additional parameters as a hashtable parameter
        if (additionalParams.size() > 0) {
            def hashtableString = "@{"
            additionalParams.each { key, value ->
                def escapedValue = value.toString().replace("'", "''")
                hashtableString += "'${key}'='${escapedValue}';"
            }
            hashtableString = hashtableString.substring(0, hashtableString.length() - 1) + "}"
            coreParamString += " -AdditionalParams ${hashtableString}"
        }
        
        def paramString = coreParamString
        
        // Log execution details
        echo "=== PowerShell Execution Details ==="
        echo "Script: runPowerShellOnRemote.ps1"
        
        // Determine actual execution mode
        def isLocalhost = parameters.RemoteHost in ['localhost', '127.0.0.1'] || parameters.RemoteHost == env.COMPUTERNAME
        if (isLocalhost) {
            echo "Execution Mode: Local (detected localhost: ${parameters.RemoteHost})"
        } else {
            echo "Execution Mode: Remote (${parameters.RemoteHost})"
            echo "Remote Host Requirements:"
            echo "  - WinRM enabled (winrm quickconfig)"
            echo "  - PowerShell Remoting enabled (Enable-PSRemoting -Force)"
            echo "  - Firewall ports open (5985 HTTP, 5986 HTTPS)"
            echo "  - Valid authentication credentials"
        }
        
        if (hasCredentials) {
            echo "Authentication: Provided credentials (${parameters.RemoteUser})"
        } else {
            echo "Authentication: Jenkins credentials"
        }
        echo "Target File: ${parameters.RemoteFile}"
        echo "Parameters for target script: ${additionalParams}"
        
        // Write the script to a temporary file
        def tempScriptName = "temp_powershell_script_${System.currentTimeMillis()}.ps1"
        writeFile file: tempScriptName, text: script
        
        // Execute PowerShell script with parameters
        try {
            def psCommand = "& '.\\${tempScriptName}'${paramString}"
            echo "Executing PowerShell command: ${psCommand.replace(parameters.RemotePassword ?: '', '***')}"
            
            powershell psCommand
            
        } finally {
            // Clean up temporary script file
            if (isUnix()) {
                sh "rm -f ${tempScriptName}"
            } else {
                bat "if exist ${tempScriptName} del ${tempScriptName}"
            }
        }
        
        echo "PowerShell script execution completed successfully"
        
    } catch (Exception e) {
        error("Failed to execute PowerShell script on remote host: ${e.getMessage()}")
    }
}
