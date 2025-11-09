#!/usr/bin/env groovy

/**
 * Execute PowerShell scripts locally or remotely
 * 
 * @param parameters Map containing:
 *   - fileName: Optional PowerShell script filename (defaults to 'runPowershell.ps1')
 *   - Date: Required date parameter
 *   - UserName: Required username parameter
 *   - RemoteHost: Optional remote host for remote execution
 *   - RemoteUser: Optional remote username
 *   - RemotePassword: Optional remote password
 *   - credentialsId: Optional Jenkins credentials ID for secure remote authentication
 *   - Any other custom parameters for the PowerShell script
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
 *   // Remote execution with Jenkins credentials (recommended)
 *   runpowerShell([
 *       Date: '2025-11-09',
 *       UserName: 'remoteuser',
 *       RemoteHost: 'server.domain.com',
 *       credentialsId: 'remote-server-credentials'
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
    def isRemoteExecution = parameters.RemoteHost && parameters.RemoteUser && parameters.RemotePassword
    
    try {
        // Load PowerShell script from resources
        def scriptFileName = parameters.fileName ?: 'runPowershell.ps1'
        def script = libraryResource "powershell/${scriptFileName}"
        
        // Build parameter string for PowerShell
        def paramString = ""
        parameters.each { key, value ->
            // Skip internal parameters that aren't PowerShell parameters
            if (key != 'fileName' && key != 'credentialsId') {
                paramString += " -${key} '${value}'"
            }
        }
        
        // Log execution details
        if (isRemoteExecution) {
            echo "Executing PowerShell script '${scriptFileName}' on remote host: ${parameters.RemoteHost}"
            echo "Remote user: ${parameters.RemoteUser}"
        } else {
            echo "Executing PowerShell script '${scriptFileName}' locally"
        }
        echo "Parameters: ${parameters.findAll { it.key != 'RemotePassword' && it.key != 'fileName' && it.key != 'credentialsId' }}"
        
        // Execute PowerShell script
        powershell(script: script + paramString)
        
        echo "PowerShell script execution completed successfully"
        
    } catch (Exception e) {
        def executionType = isRemoteExecution ? "remote" : "local"
        error("Failed to execute PowerShell script (${executionType}): ${e.getMessage()}")
    }
}
