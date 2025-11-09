#!/usr/bin/env groovy

/**
 * Execute PowerShell scripts locally or remotely using Invoke-Command
 * 
 * @param parameters Map containing:
 *   - fileName: Optional PowerShell script filename (defaults to 'runPowershell.ps1')
 *   - Date: Required date parameter
 *   - UserName: Required username parameter
 *   - RemoteHost: Optional remote host for remote execution via Invoke-Command
 *   - RemoteUser: Optional remote username for authentication
 *   - RemotePassword: Optional remote password for authentication
 *   - RemoteFile: Optional remote script file path to execute via Invoke-Command -FilePath
 *   - credentialsId: Optional Jenkins credentials ID for secure remote authentication
 *   - Any other custom parameters will be passed to the PowerShell script
 * 
 * Examples:
 *   // Local execution
 *   runpowerShell([
 *       Date: '2025-11-09',
 *       UserName: 'localuser'
 *   ])
 *
 *   // Remote execution with direct credentials
 *   runpowerShell([
 *       Date: '2025-11-09',
 *       UserName: 'remoteuser',
 *       RemoteHost: 'server.domain.com',
 *       RemoteUser: 'admin',
 *       RemotePassword: 'password123'
 *   ])
 *
 *   // Remote execution with Jenkins credentials
 *   runpowerShell([
 *       Date: '2025-11-09',
 *       UserName: 'remoteuser',
 *       RemoteHost: 'server.domain.com',
 *       credentialsId: 'remote-server-credentials'
 *   ])
 *
 *   // Remote execution with remote script file
 *   runpowerShell([
 *       Date: '2025-11-09',
 *       UserName: 'remoteuser',
 *       RemoteHost: 'server.domain.com',
 *       RemoteFile: 'C:\\Scripts\\MyScript.ps1',
 *       credentialsId: 'remote-server-credentials',
 *       Environment: 'Production',
 *       LogLevel: 'Debug'
 *   ])
 */
def call(Map parameters = [:]) {
    // Validate required parameters
    if (!parameters.Date) {
        error("Parameter 'Date' is required")
    }
    if (!parameters.UserName) {
        error("Parameter 'UserName' is required")
    }
    
    // Check if Jenkins credentials should be used
    if (parameters.credentialsId) {
        echo "Using Jenkins credentials for remote authentication"
        withCredentials(parameters, parameters.credentialsId)
    } else {
        // Direct execution without Jenkins credentials
        executeScript(parameters)
    }
}

/**
 * Execute PowerShell scripts with credential support from Jenkins
 * 
 * @param parameters Map containing script parameters
 * @param credentialsId Jenkins credentials ID for remote authentication
 */
def withCredentials(Map parameters, String credentialsId) {
    withCredentials([usernamePassword(
        credentialsId: credentialsId,
        usernameVariable: 'REMOTE_USER',
        passwordVariable: 'REMOTE_PASS'
    )]) {
        // Add credentials to parameters
        def enhancedParams = parameters.clone()
        enhancedParams.RemoteUser = env.REMOTE_USER
        enhancedParams.RemotePassword = env.REMOTE_PASS
        
        // Remove credentialsId from parameters to avoid passing it to PowerShell
        enhancedParams.remove('credentialsId')
        
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
    def isRemoteExecution = parameters.RemoteHost
    def hasRemoteFile = parameters.RemoteFile
    def hasCredentials = parameters.RemoteUser && parameters.RemotePassword
    
    try {
        // Load PowerShell script from resources
        def scriptFileName = parameters.fileName ?: 'runPowershell.ps1'
        def script = libraryResource "powershell/${scriptFileName}"
        
        // Build parameter string for PowerShell
        def paramString = ""
        parameters.each { key, value ->
            // Skip internal parameters that aren't PowerShell parameters
            if (key != 'fileName' && key != 'credentialsId') {
                // Handle special characters in parameter values
                def escapedValue = value.toString().replace("'", "''")
                paramString += " -${key} '${escapedValue}'"
            }
        }
        
        // Log execution details
        echo "=== PowerShell Execution Details ==="
        echo "Script: ${scriptFileName}"
        if (isRemoteExecution) {
            echo "Execution Mode: Remote (${parameters.RemoteHost})"
            if (hasCredentials) {
                echo "Authentication: Provided credentials (${parameters.RemoteUser})"
            } else {
                echo "Authentication: Current user credentials"
            }
            if (hasRemoteFile) {
                echo "Remote File: ${parameters.RemoteFile}"
            } else {
                echo "Script Mode: Inline script block"
            }
        } else {
            echo "Execution Mode: Local"
        }
        echo "Parameters: ${parameters.findAll { it.key != 'RemotePassword' && it.key != 'fileName' && it.key != 'credentialsId' }}"
        
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
        def executionType = isRemoteExecution ? "remote" : "local"
        error("Failed to execute PowerShell script (${executionType}): ${e.getMessage()}")
    }
}
