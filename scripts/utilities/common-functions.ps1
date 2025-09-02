# ========================================================================
# Common Functions Library for Hazelcast Demo Scripts
# ========================================================================
# Collection of reusable PowerShell functions for all deployment scripts
# Author: Antonio Galluzzi (antonio.galluzzi91@gmail.com)
# Version: 2.0.0
# ========================================================================

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# ========================================================================
# GLOBAL CONFIGURATION
# ========================================================================

# Application Constants
$Global:APP_NAME = "hazelcast-demo"
$Global:PROJECT_NAME = "hazelcast-demo-dev"
$Global:DB_NAME = "postgresql"
$Global:DB_USER = "hazelcast"
$Global:DB_PASSWORD = "hazelcast123"

# Script Configuration
$Global:MAX_RETRIES = 3
$Global:RETRY_DELAY = 10
$Global:DEFAULT_TIMEOUT = 300

# Colors for consistent output
$Global:Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Cyan"
    White = "White"
    Gray = "Gray"
}

# Log levels
$Global:LogLevels = @{
    TRACE = 0
    DEBUG = 1
    INFO = 2
    WARN = 3
    ERROR = 4
    FATAL = 5
}

# Current log level (can be overridden)
$Global:CurrentLogLevel = $LogLevels.INFO

# ========================================================================
# UTILITY FUNCTIONS
# ========================================================================

function Write-ColorOutput {
    <#
    .SYNOPSIS
    Writes colored output to console with consistent formatting
    .PARAMETER Color
    Color name from $Global:Colors
    .PARAMETER Level
    Log level string
    .PARAMETER Message
    Message to display
    #>
    param(
        [string]$Color,
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Level] $Message" -ForegroundColor $Color
}

function Write-Log {
    <#
    .SYNOPSIS
    Advanced logging function with levels and file output
    .PARAMETER Level
    Log level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
    .PARAMETER Message
    Message to log
    .PARAMETER LogFile
    Optional log file path
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$LogFile
    )
    
    # Check if we should log this level
    if ($LogLevels[$Level] -lt $CurrentLogLevel) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp][$Level] $Message"
    
    # Choose color based on level
    $color = switch ($Level) {
        "TRACE" { $Colors.Gray }
        "DEBUG" { $Colors.Blue }
        "INFO" { $Colors.White }
        "WARN" { $Colors.Yellow }
        "ERROR" { $Colors.Red }
        "FATAL" { $Colors.Red }
        default { $Colors.White }
    }
    
    # Output to console
    Write-Host $logEntry -ForegroundColor $color
    
    # Output to file if specified
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    }
}

function Write-Info {
    param([string]$Message, [string]$LogFile)
    Write-Log -Level "INFO" -Message $Message -LogFile $LogFile
}

function Write-Success {
    param([string]$Message, [string]$LogFile)
    Write-Log -Level "INFO" -Message "✅ $Message" -LogFile $LogFile
}

function Write-Warning {
    param([string]$Message, [string]$LogFile)
    Write-Log -Level "WARN" -Message "⚠️ $Message" -LogFile $LogFile
}

function Write-Error {
    param([string]$Message, [string]$LogFile)
    Write-Log -Level "ERROR" -Message "❌ $Message" -LogFile $LogFile
}

function Write-Debug {
    param([string]$Message, [string]$LogFile)
    Write-Log -Level "DEBUG" -Message "🔍 $Message" -LogFile $LogFile
}

# ========================================================================
# RETRY AND RESILIENCE FUNCTIONS
# ========================================================================

function Invoke-WithRetry {
    <#
    .SYNOPSIS
    Executes a script block with retry logic and exponential backoff
    .PARAMETER ScriptBlock
    Script block to execute
    .PARAMETER OperationName
    Name of the operation for logging
    .PARAMETER MaxRetries
    Maximum number of retries
    .PARAMETER DelaySeconds
    Initial delay between retries
    .PARAMETER ExponentialBackoff
    Use exponential backoff for delays
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory=$true)]
        [string]$OperationName,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = $Global:MAX_RETRIES,
        
        [Parameter(Mandatory=$false)]
        [int]$DelaySeconds = $Global:RETRY_DELAY,
        
        [Parameter(Mandatory=$false)]
        [switch]$ExponentialBackoff
    )
    
    $attempt = 1
    $currentDelay = $DelaySeconds
    
    while ($attempt -le $MaxRetries) {
        try {
            Write-Info "🔄 $OperationName (attempt $attempt/$MaxRetries)"
            
            $result = & $ScriptBlock
            
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
                Write-Success "$OperationName succeeded on attempt $attempt"
                return $result
            }
            else {
                throw "Command failed with exit code $LASTEXITCODE"
            }
        }
        catch {
            Write-Warning "$OperationName failed on attempt $attempt`: $($_.Exception.Message)"
            
            if ($attempt -eq $MaxRetries) {
                Write-Error "$OperationName failed after $MaxRetries attempts"
                throw
            }
            
            Write-Info "⏳ Waiting $currentDelay seconds before retry..."
            Start-Sleep -Seconds $currentDelay
            
            if ($ExponentialBackoff) {
                $currentDelay = $currentDelay * 2
            }
            
            $attempt++
        }
    }
}

# ========================================================================
# CHECKPOINT AND RECOVERY FUNCTIONS
# ========================================================================

function Save-Checkpoint {
    <#
    .SYNOPSIS
    Saves deployment checkpoint for recovery
    .PARAMETER State
    Current deployment state
    .PARAMETER Message
    Optional message
    .PARAMETER CheckpointFile
    Checkpoint file path
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$State,
        
        [Parameter(Mandatory=$false)]
        [string]$Message = "",
        
        [Parameter(Mandatory=$false)]
        [string]$CheckpointFile = ".\.deployment-checkpoint"
    )
    
    $checkpoint = @{
        State = $State
        Timestamp = Get-Date
        Message = $Message
        ProjectName = $Global:PROJECT_NAME
        AppName = $Global:APP_NAME
    }
    
    $checkpoint | ConvertTo-Json | Out-File -FilePath $CheckpointFile -Encoding UTF8
    Write-Info "📍 Checkpoint saved: $State $(if($Message) { "- $Message" })"
}

function Get-Checkpoint {
    <#
    .SYNOPSIS
    Retrieves deployment checkpoint
    .PARAMETER CheckpointFile
    Checkpoint file path
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$CheckpointFile = ".\.deployment-checkpoint"
    )
    
    if (Test-Path $CheckpointFile) {
        try {
            $checkpoint = Get-Content $CheckpointFile | ConvertFrom-Json
            return $checkpoint
        }
        catch {
            Write-Warning "Invalid checkpoint file, starting fresh"
            Remove-Item $CheckpointFile -Force -ErrorAction SilentlyContinue
            return $null
        }
    }
    return $null
}

function Clear-Checkpoint {
    <#
    .SYNOPSIS
    Clears deployment checkpoint
    .PARAMETER CheckpointFile
    Checkpoint file path
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$CheckpointFile = ".\.deployment-checkpoint"
    )
    
    if (Test-Path $CheckpointFile) {
        Remove-Item $CheckpointFile -Force -ErrorAction SilentlyContinue
        Write-Info "🧹 Checkpoint cleared"
    }
}

# ========================================================================
# ENVIRONMENT DETECTION FUNCTIONS
# ========================================================================

function Test-Command {
    <#
    .SYNOPSIS
    Tests if a command is available in PATH
    .PARAMETER CommandName
    Name of the command to test
    #>
    param([string]$CommandName)
    
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $command
}

function Test-JavaInstallation {
    <#
    .SYNOPSIS
    Tests Java installation and version
    .PARAMETER MinVersion
    Minimum required Java version
    #>
    param([int]$MinVersion = 17)
    
    Write-Info "🔍 Checking Java installation..."
    
    if (-not (Test-Command "java")) {
        Write-Error "Java is not installed or not in PATH"
        return $false
    }
    
    try {
        $javaOutput = & java -version 2>&1
        $versionLine = $javaOutput | Where-Object { $_ -match "version" } | Select-Object -First 1
        
        if ($versionLine -match '"([^"]+)"') {
            $javaVersion = $matches[1]
            $majorVersion = ($javaVersion -split '\.')[0]
            
            if ([int]$majorVersion -lt $MinVersion) {
                Write-Error "Java version $javaVersion is not supported. Please use Java $MinVersion or higher"
                return $false
            }
            
            Write-Success "Java $javaVersion detected"
            return $true
        }
    }
    catch {
        Write-Error "Failed to check Java version: $($_.Exception.Message)"
        return $false
    }
}

function Test-MavenInstallation {
    <#
    .SYNOPSIS
    Tests Maven installation
    #>
    
    Write-Info "🔍 Checking Maven installation..."
    
    # Check for Maven wrapper first
    if (Test-Path ".\mvnw.cmd") {
        Write-Success "Maven wrapper found"
        return $true
    }
    
    # Check for system Maven
    if (Test-Command "mvn") {
        $mvnVersion = & mvn -version 2>&1 | Select-Object -First 1
        Write-Success "System Maven found: $mvnVersion"
        return $true
    }
    
    Write-Error "Maven is not available (no wrapper and not in PATH)"
    return $false
}

function Test-DockerInstallation {
    <#
    .SYNOPSIS
    Tests Docker installation
    #>
    
    Write-Info "🔍 Checking Docker installation..."
    
    if (-not (Test-Command "docker")) {
        Write-Warning "Docker is not installed or not in PATH"
        return $false
    }
    
    try {
        $dockerVersion = & docker --version 2>&1
        Write-Success "Docker detected: $dockerVersion"
        
        # Test if Docker daemon is running
        & docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker daemon is running"
            return $true
        } else {
            Write-Warning "Docker is installed but daemon is not running"
            return $false
        }
    }
    catch {
        Write-Warning "Docker check failed: $($_.Exception.Message)"
        return $false
    }
}

# ========================================================================
# APPLICATION STATUS FUNCTIONS
# ========================================================================

function Test-ApplicationRunning {
    <#
    .SYNOPSIS
    Tests if application is running on specified port
    .PARAMETER Port
    Port to test
    .PARAMETER Timeout
    Timeout in seconds
    #>
    param(
        [int]$Port = 8080,
        [int]$Timeout = 10
    )
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/actuator/health" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $health = $response.Content | ConvertFrom-Json
            return @{
                Running = $true
                Status = $health.status
                Details = $health
                Port = $Port
            }
        }
    } catch {
        # Application not running or not responding
    }
    
    return @{
        Running = $false
        Status = "DOWN"
        Details = $null
        Port = $Port
    }
}

function Get-JavaProcesses {
    <#
    .SYNOPSIS
    Gets Java processes related to the application
    #>
    
    try {
        $javaProcesses = Get-Process | Where-Object { $_.ProcessName -match "java" }
        $springBootProcesses = @()
        
        foreach ($process in $javaProcesses) {
            try {
                $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
                if ($commandLine -match "spring-boot|hazelcast-demo") {
                    # Extract port from command line
                    $port = 8080  # default
                    if ($commandLine -match "server\.port=(\d+)") {
                        $port = [int]$matches[1]
                    }
                    
                    $springBootProcesses += @{
                        Id = $process.Id
                        Name = $process.ProcessName
                        StartTime = $process.StartTime
                        CPU = $process.CPU
                        Memory = [math]::Round($process.WorkingSet64 / 1MB, 2)
                        CommandLine = $commandLine
                        Port = $port
                    }
                }
            } catch {
                # Skip processes we can't access
            }
        }
        
        return $springBootProcesses
    } catch {
        return @()
    }
}

function Get-RunningInstances {
    <#
    .SYNOPSIS
    Gets all running application instances
    #>
    
    $instances = @()
    $javaProcesses = Get-JavaProcesses
    
    # Check common ports for running instances
    $commonPorts = @(8080, 8081, 8082, 8083, 8084, 8085)
    
    foreach ($port in $commonPorts) {
        $appStatus = Test-ApplicationRunning -Port $port -Timeout 5
        if ($appStatus.Running) {
            $process = $javaProcesses | Where-Object { $_.Port -eq $port } | Select-Object -First 1
            $instances += @{
                Port = $port
                Status = $appStatus.Status
                Process = $process
                Health = $appStatus.Details
            }
        }
    }
    
    return $instances
}

# ========================================================================
# KUBERNETES/OPENSHIFT FUNCTIONS
# ========================================================================

function Test-OCCommand {
    <#
    .SYNOPSIS
    Tests OpenShift CLI availability
    #>
    
    Write-Info "🔍 Checking OpenShift CLI (oc) installation..."
    
    if (-not (Test-Command "oc")) {
        Write-Error "OpenShift CLI (oc) is not installed or not in PATH"
        Write-Info "💡 Download from: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
        return $false
    }
    
    try {
        $ocVersion = oc version --client=true 2>$null
        Write-Success "OpenShift CLI found: $($ocVersion | Select-Object -First 1)"
        
        # Test cluster connectivity
        $serverStatus = oc whoami --show-server 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Connected to cluster: $serverStatus"
        } else {
            Write-Warning "Not connected to any cluster"
        }
        
        return $true
    }
    catch {
        Write-Warning "Could not verify oc connectivity: $($_.Exception.Message)"
        return $false
    }
}

function Test-ClusterConnection {
    <#
    .SYNOPSIS
    Tests cluster connection
    #>
    
    try {
        $currentUser = oc whoami 2>$null
        return ($null -ne $currentUser -and $currentUser -ne "")
    } catch {
        return $false
    }
}

function Get-CurrentProject {
    <#
    .SYNOPSIS
    Gets current OpenShift project
    #>
    
    try {
        $project = oc project -q 2>$null
        return $project
    } catch {
        return $null
    }
}

# ========================================================================
# BUILD AND DEPLOYMENT FUNCTIONS
# ========================================================================

function Invoke-MavenBuild {
    <#
    .SYNOPSIS
    Executes Maven build with specified goals
    .PARAMETER Goals
    Maven goals to execute
    .PARAMETER Profile
    Maven profile to use
    .PARAMETER SkipTests
    Skip tests during build
    #>
    param(
        [string]$Goals = "clean package",
        [string]$MavenProfile = "",
        [switch]$SkipTests
    )
    
    $mvnCmd = if (Test-Path ".\mvnw.cmd") { ".\mvnw.cmd" } else { "mvn" }
    
    $buildParams = $Goals -split ' '
    
    if ($MavenProfile) {
        $buildParams += "-P$MavenProfile"
    }
    
    if ($SkipTests) {
        $buildParams += "-DskipTests"
    }
    
    Write-Info "🔨 Running Maven build: $mvnCmd $($buildParams -join ' ')"
    
    & $mvnCmd @buildParams
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Maven build completed successfully"
        return $true
    } else {
        Write-Error "Maven build failed"
        return $false
    }
}

function Invoke-DockerBuild {
    <#
    .SYNOPSIS
    Builds Docker image
    .PARAMETER ImageName
    Docker image name
    .PARAMETER Tag
    Docker image tag
    .PARAMETER BuildContext
    Build context path
    #>
    param(
        [string]$ImageName = $Global:APP_NAME,
        [string]$Tag = "latest",
        [string]$BuildContext = "."
    )
    
    $fullImageName = "${ImageName}:${Tag}"
    
    Write-Info "🐳 Building Docker image: $fullImageName"
    
    docker build -t $fullImageName $BuildContext
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker image built successfully: $fullImageName"
        return $true
    } else {
        Write-Error "Docker build failed"
        return $false
    }
}

# ========================================================================
# CONFIGURATION FUNCTIONS
# ========================================================================

function Get-EnvironmentConfig {
    <#
    .SYNOPSIS
    Gets configuration for specified environment
    .PARAMETER Environment
    Environment name (dev, staging, prod, openshift-local)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("dev", "staging", "prod", "openshift-local", "cloud")]
        [string]$Environment
    )
    
    $configs = @{
        "dev" = @{
            Profile = "dev"
            Database = "H2"
            Port = 8080
            HazelcastDiscovery = "multicast"
            LogLevel = "DEBUG"
        }
        "staging" = @{
            Profile = "staging"
            Database = "PostgreSQL"
            Port = 8080
            HazelcastDiscovery = "tcp-ip"
            LogLevel = "INFO"
        }
        "prod" = @{
            Profile = "prod"
            Database = "PostgreSQL"
            Port = 8080
            HazelcastDiscovery = "kubernetes"
            LogLevel = "WARN"
        }
        "openshift-local" = @{
            Profile = "openshift-local"
            Database = "PostgreSQL"
            Port = 8080
            HazelcastDiscovery = "kubernetes"
            LogLevel = "INFO"
        }
        "cloud" = @{
            Profile = "cloud"
            Database = "PostgreSQL"
            Port = 8080
            HazelcastDiscovery = "kubernetes"
            LogLevel = "INFO"
        }
    }
    
    return $configs[$Environment]
}

# ========================================================================
# PROGRESS AND UI FUNCTIONS
# ========================================================================

function Show-Progress {
    <#
    .SYNOPSIS
    Shows progress bar for long-running operations
    .PARAMETER Activity
    Activity description
    .PARAMETER CurrentOperation
    Current operation
    .PARAMETER PercentComplete
    Percentage complete
    #>
    param(
        [string]$Activity,
        [string]$CurrentOperation,
        [int]$PercentComplete
    )
    
    Write-Progress -Activity $Activity -Status $CurrentOperation -PercentComplete $PercentComplete
}

function Wait-ForCondition {
    <#
    .SYNOPSIS
    Waits for a condition to be met with timeout
    .PARAMETER ScriptBlock
    Script block to evaluate
    .PARAMETER TimeoutSeconds
    Timeout in seconds
    .PARAMETER PollingInterval
    Polling interval in seconds
    .PARAMETER Description
    Description for progress
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [int]$TimeoutSeconds = $Global:DEFAULT_TIMEOUT,
        [int]$PollingInterval = 5,
        [string]$Description = "Waiting for condition"
    )
    
    $startTime = Get-Date
    $elapsed = 0
    
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $result = & $ScriptBlock
            if ($result) {
                Write-Success "$Description completed after $elapsed seconds"
                return $true
            }
        } catch {
            Write-Debug "Condition check failed: $($_.Exception.Message)"
        }
        
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
        $percentComplete = [math]::Min(($elapsed / $TimeoutSeconds) * 100, 100)
        
        Show-Progress -Activity $Description -CurrentOperation "Elapsed: ${elapsed}s / ${TimeoutSeconds}s" -PercentComplete $percentComplete
        
        Start-Sleep -Seconds $PollingInterval
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
    }
    
    Write-Progress -Activity $Description -Completed
    Write-Warning "$Description timed out after $TimeoutSeconds seconds"
    return $false
}

# ========================================================================
# Script completed successfully - all functions are now available
