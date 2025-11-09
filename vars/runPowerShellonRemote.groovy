#!/usr/bin/env groovy

/**
 * Execute PowerShell scripts locally or remotely using Invoke-Command
 * 
 * @param parameters Map containing:
 *   - fileName: Optional PowerShell script filename (defaults to 'runPowerShellOnRemote.ps1')
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
        def scriptFileName = parameters.fileName ?: 'runPowerShellOnRemote.ps1'
        def script = libraryResource "powershell/${scriptFileName}"
        
        // Build parameter string for PowerShell
        def paramString = ""
        def internalParams = ['fileName', 'RemoteCredentialsId']
        
        parameters.each { key, value ->
            // Skip only internal Jenkins parameters that aren't PowerShell parameters
            if (key not in internalParams) {
                // Handle special characters in parameter values
                def escapedValue = value.toString().replace("'", "''")
                paramString += " -${key} '${escapedValue}'"
            }
        }
        
        // Log execution details
        echo "=== PowerShell Execution Details ==="
        echo "Script: ${scriptFileName}"
        echo "Execution Mode: Remote (${parameters.RemoteHost})"
        if (hasCredentials) {
            echo "Authentication: Provided credentials (${parameters.RemoteUser})"
        } else {
            echo "Authentication: Jenkins credentials"
        }
        echo "Remote File: ${parameters.RemoteFile}"
        echo "Parameters: ${parameters.findAll { it.key != 'RemotePassword' && it.key not in internalParams }}"
        
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
