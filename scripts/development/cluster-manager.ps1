# ========================================================================
# Local Cluster Manager for Hazelcast Demo
# ========================================================================
# Advanced cluster management for local development with multi-instance support
# Author: Antonio Galluzzi (antonio.galluzzi91@gmail.com)
# Version: 2.0.0
# ========================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("start", "stop", "restart", "status", "test", "scale", "logs", "cleanup")]
    [string]$Action = "status",
    
    [Parameter(Mandatory=$false)]
    [int]$Instances = 2,
    
    [Parameter(Mandatory=$false)]
    [int]$StartPort = 8080,
    
    [Parameter(Mandatory=$false)]
    [string]$Profile = "dev",
    
    [Parameter(Mandatory=$false)]
    [int]$WaitTimeout = 180,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$Background,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# Set error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import common functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonFunctionsPath = Join-Path (Split-Path $scriptDir) "utilities\common-functions.ps1"

if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Host "ERROR: Cannot find common-functions.ps1" -ForegroundColor Red
    exit 1
}

# ========================================================================
# GLOBAL CONFIGURATION
# ========================================================================

$Global:ClusterConfig = @{
    Name = "hazelcast-demo-local-cluster"
    Profile = $Profile
    StartPort = $StartPort
    Instances = $Instances
    WaitTimeout = $WaitTimeout
    LogsDirectory = "logs\cluster"
    StateFile = ".cluster-state.json"
    ProcessPrefix = "HazelcastDemo"
}

# Job tracking for cleanup
$Global:TrackedJobs = @()

# ========================================================================
# UTILITY FUNCTIONS
# ========================================================================

function Get-ClusterPorts {
    <#
    .SYNOPSIS
    Gets array of ports for cluster instances
    #>
    
    $ports = @()
    for ($i = 0; $i -lt $Global:ClusterConfig.Instances; $i++) {
        $ports += $Global:ClusterConfig.StartPort + $i
    }
    return $ports
}

function Get-ClusterState {
    <#
    .SYNOPSIS
    Gets current cluster state from file
    #>
    
    $stateFile = $Global:ClusterConfig.StateFile
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile | ConvertFrom-Json
            return $state
        } catch {
            Write-Warning "Invalid cluster state file, starting fresh"
            Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    return @{
        LastStart = $null
        Instances = @()
        ExpectedPorts = @()
        Status = "STOPPED"
    }
}

function Save-ClusterState {
    <#
    .SYNOPSIS
    Saves cluster state to file
    #>
    param($State)
    
    $stateFile = $Global:ClusterConfig.StateFile
    $State | ConvertTo-Json -Depth 5 | Out-File -FilePath $stateFile -Encoding UTF8
}

function Clear-ClusterState {
    <#
    .SYNOPSIS
    Clears cluster state file
    #>
    
    $stateFile = $Global:ClusterConfig.StateFile
    if (Test-Path $stateFile) {
        Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
        Write-Info "🧹 Cluster state cleared"
    }
}

function Initialize-LogsDirectory {
    <#
    .SYNOPSIS
    Initializes cluster logs directory
    #>
    
    $logsDir = $Global:ClusterConfig.LogsDirectory
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        Write-Success "Created cluster logs directory: $logsDir"
    }
}

function Clear-BackgroundJobs {
    <#
    .SYNOPSIS
    Cleans up background jobs
    #>
    
    Write-Info "🧹 Cleaning up background jobs..."
    
    try {
        # Get all jobs related to our cluster
        $jobs = Get-Job | Where-Object { 
            $_.Name -like "$($Global:ClusterConfig.ProcessPrefix)*" -or 
            $_.Command -like "*spring-boot:run*" 
        }
        
        if ($jobs) {
            foreach ($job in $jobs) {
                try {
                    Write-Debug "Stopping job: $($job.Name) (ID: $($job.Id))"
                    Stop-Job -Job $job -ErrorAction SilentlyContinue
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Warning "Could not clean job $($job.Id): $($_.Exception.Message)"
                }
            }
            Write-Success "✅ Background jobs cleaned"
        } else {
            Write-Debug "No background jobs to clean"
        }
    } catch {
        Write-Warning "Error during job cleanup: $($_.Exception.Message)"
    }
}

# Register cleanup on script exit
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Clear-BackgroundJobs
} | Out-Null

# Trap for handling Ctrl+C
trap {
    Write-Warning "Script interrupted. Cleaning up..."
    Clear-BackgroundJobs
    exit 1
}

# ========================================================================
# CLUSTER MANAGEMENT FUNCTIONS
# ========================================================================

function Start-ClusterInstances {
    <#
    .SYNOPSIS
    Starts cluster instances
    #>
    
    Write-Host ""
    Write-Host "🚀 Starting Hazelcast Local Cluster" -ForegroundColor $Colors.White
    Write-Host "====================================" -ForegroundColor $Colors.White
    Write-Host ""
    
    # Verify prerequisites
    if (-not (Test-Path "pom.xml")) {
        throw "Not in project root directory (pom.xml not found)"
    }
    
    if (-not (Test-JavaInstallation)) {
        throw "Java is required for cluster startup"
    }
    
    if (-not (Test-MavenInstallation)) {
        throw "Maven is required for cluster startup"
    }
    
    # Initialize logs directory
    Initialize-LogsDirectory
    
    # Get cluster ports
    $clusterPorts = Get-ClusterPorts
    
    Write-Info "Cluster Configuration:"
    Write-Host "  • Name: $($Global:ClusterConfig.Name)" -ForegroundColor $Colors.White
    Write-Host "  • Instances: $($Global:ClusterConfig.Instances)" -ForegroundColor $Colors.White
    Write-Host "  • Profile: $($Global:ClusterConfig.Profile)" -ForegroundColor $Colors.White
    Write-Host "  • Ports: $($clusterPorts -join ', ')" -ForegroundColor $Colors.White
    Write-Host ""
    
    # Check for conflicts
    $conflictingPorts = @()
    foreach ($port in $clusterPorts) {
        $appStatus = Test-ApplicationRunning -Port $port -Timeout 3
        if ($appStatus.Running) {
            $conflictingPorts += $port
        }
    }
    
    if ($conflictingPorts.Count -gt 0) {
        if ($Force) {
            Write-Warning "Ports $($conflictingPorts -join ', ') are in use but Force mode enabled"
            Write-Info "Stopping existing instances..."
            Stop-ClusterInstances
        } else {
            Write-Error "Ports $($conflictingPorts -join ', ') are already in use"
            Write-Info "Use -Force to stop existing instances or choose different ports"
            return $false
        }
    }
    
    Write-Success "🚀 Starting $($Global:ClusterConfig.Instances) cluster instances..."
    
    $startTime = Get-Date
    $instancesStarted = @()
    
    # Start instances
    for ($i = 0; $i -lt $Global:ClusterConfig.Instances; $i++) {
        $port = $clusterPorts[$i]
        $instanceName = "$($Global:ClusterConfig.ProcessPrefix)-$port"
        $logFile = Join-Path $Global:ClusterConfig.LogsDirectory "instance-$port.log"
        
        Write-Info "Starting instance $($i + 1) on port $port..."
        
        try {
            if ($Background) {
                # Start in background job
                $job = Start-Job -Name $instanceName -WorkingDirectory (Get-Location) -ScriptBlock {
                    param($Port, $AppProfile, $LogFile)
                    
                    # Redirect output to log file
                    $mvnCmd = if (Test-Path ".\mvnw.cmd") { ".\mvnw.cmd" } else { "mvn" }
                    & $mvnCmd spring-boot:run `
                        "-Dspring-boot.run.profiles=$AppProfile" `
                        "-Dspring-boot.run.jvmArguments=-Dserver.port=$Port" `
                        2>&1 | Tee-Object -FilePath $LogFile
                        
                } -ArgumentList $port, $Global:ClusterConfig.Profile, $logFile
                
                $Global:TrackedJobs += $job
                
                $instancesStarted += @{
                    Port = $port
                    JobId = $job.Id
                    JobName = $instanceName
                    LogFile = $logFile
                    StartTime = Get-Date
                }
                
                Write-Success "✅ Background job started for instance $($i + 1) (Job ID: $($job.Id))"
            } else {
                # Start in foreground (only for single instance)
                if ($Global:ClusterConfig.Instances -eq 1) {
                    Write-Warning "Starting single instance in foreground. Press Ctrl+C to stop."
                    Start-Sleep 2
                    
                    $mvnCmd = if (Test-Path ".\mvnw.cmd") { ".\mvnw.cmd" } else { "mvn" }
                    & $mvnCmd spring-boot:run `
                        "-Dspring-boot.run.profiles=$($Global:ClusterConfig.Profile)" `
                        "-Dspring-boot.run.jvmArguments=-Dserver.port=$port"
                    return $true
                } else {
                    Write-Warning "Multiple instances require background mode"
                    $Background = $true
                    # Recursively call with background enabled
                    Start-ClusterInstances
                    return
                }
            }
        } catch {
            Write-Error "❌ Failed to start instance $($i + 1): $($_.Exception.Message)"
            continue
        }
        
        # Small delay between starts to avoid port conflicts
        Start-Sleep 3
    }
    
    if ($Background) {
        # Wait for instances to start
        Write-Info "⏳ Waiting for instances to start (max $($Global:ClusterConfig.WaitTimeout)s)..."
        
        $allReady = Wait-ForCondition -ScriptBlock {
            $readyCount = 0
            foreach ($instance in $instancesStarted) {
                $appStatus = Test-ApplicationRunning -Port $instance.Port -Timeout 3
                if ($appStatus.Running) {
                    $readyCount++
                }
            }
            return $readyCount -eq $instancesStarted.Count
        } -TimeoutSeconds $Global:ClusterConfig.WaitTimeout -Description "Waiting for all instances to start"
        
        if ($allReady) {
            $elapsedTime = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
            Write-Success "🎉 All $($Global:ClusterConfig.Instances) instances are running! (${elapsedTime}s)"
            
            # Save cluster state
            $clusterState = @{
                LastStart = Get-Date
                Instances = $instancesStarted
                ExpectedPorts = $clusterPorts
                Status = "RUNNING"
                Profile = $Global:ClusterConfig.Profile
            }
            Save-ClusterState $clusterState
            
            # Show cluster status
            Show-ClusterStatus
            
            # Test cluster functionality
            Write-Info "⏳ Waiting for cluster formation..."
            Start-Sleep 10
            Test-ClusterFunctionality
            
            return $true
        } else {
            Write-Warning "⚠️ Not all instances started within timeout"
            Show-ClusterStatus
            return $false
        }
    }
}

function Stop-ClusterInstances {
    <#
    .SYNOPSIS
    Stops cluster instances
    #>
    
    Write-Host ""
    Write-Host "🛑 Stopping Hazelcast Local Cluster" -ForegroundColor $Colors.Yellow
    Write-Host "====================================" -ForegroundColor $Colors.Yellow
    Write-Host ""
    
    $clusterState = Get-ClusterState
    $runningInstances = Get-RunningInstances
    
    if ($runningInstances.Count -eq 0) {
        Write-Info "No cluster instances are currently running"
        Clear-ClusterState
        return $true
    }
    
    Write-Info "🛑 Stopping $($runningInstances.Count) running instances..."
    
    # Try graceful shutdown first
    foreach ($instance in $runningInstances) {
        try {
            Write-Info "Requesting graceful shutdown for port $($instance.Port)..."
            $shutdownUrl = "http://localhost:$($instance.Port)/actuator/shutdown"
            Invoke-WebRequest -Uri $shutdownUrl -Method POST -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue | Out-Null
        } catch {
            Write-Debug "Graceful shutdown failed for port $($instance.Port)"
        }
    }
    
    # Wait for graceful shutdown
    Write-Info "⏳ Waiting for graceful shutdown (30s)..."
    $gracefulSuccess = Wait-ForCondition -ScriptBlock {
        $stillRunning = Get-RunningInstances
        return $stillRunning.Count -eq 0
    } -TimeoutSeconds 30 -PollingInterval 2 -Description "Graceful shutdown"
    
    if ($gracefulSuccess) {
        Write-Success "✅ All instances stopped gracefully"
    } else {
        Write-Warning "Some instances did not stop gracefully, forcing termination..."
        
        # Clean up PowerShell background jobs
        Clear-BackgroundJobs
        
        # Force kill any remaining Java processes
        $javaProcesses = Get-JavaProcesses
        if ($javaProcesses.Count -gt 0) {
            foreach ($proc in $javaProcesses) {
                try {
                    $process = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
                    if ($process) {
                        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                        Write-Success "Terminated process PID: $($proc.Id)"
                    }
                } catch {
                    Write-Warning "Could not terminate process PID: $($proc.Id)"
                }
            }
        }
    }
    
    # Final verification
    Start-Sleep 2
    $finalCheck = Get-RunningInstances
    if ($finalCheck.Count -eq 0) {
        Write-Success "✅ All cluster instances stopped successfully"
        
        # Update cluster state
        $clusterState.Status = "STOPPED"
        $clusterState.Instances = @()
        Save-ClusterState $clusterState
        
        return $true
    } else {
        Write-Warning "Some instances may still be running"
        return $false
    }
}

function Restart-ClusterInstances {
    <#
    .SYNOPSIS
    Restarts cluster instances
    #>
    
    Write-Host ""
    Write-Host "🔄 Restarting Hazelcast Local Cluster" -ForegroundColor $Colors.Blue
    Write-Host "======================================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    Write-Info "Restarting cluster with $($Global:ClusterConfig.Instances) instances..."
    
    # Stop existing instances
    $stopResult = Stop-ClusterInstances
    if (-not $stopResult -and -not $Force) {
        Write-Error "Failed to stop existing instances. Use -Force to continue anyway."
        return $false
    }
    
    # Wait a moment for cleanup
    Start-Sleep 3
    
    # Start new instances
    return Start-ClusterInstances
}

function Show-ClusterStatus {
    <#
    .SYNOPSIS
    Shows detailed cluster status
    #>
    
    Write-Host ""
    Write-Host "📊 Hazelcast Local Cluster Status" -ForegroundColor $Colors.White
    Write-Host "==================================" -ForegroundColor $Colors.White
    Write-Host ""
    
    $clusterState = Get-ClusterState
    $runningInstances = Get-RunningInstances
    
    # Cluster overview
    Write-Info "Cluster Overview:"
    Write-Host "  • Name: $($Global:ClusterConfig.Name)" -ForegroundColor $Colors.White
    Write-Host "  • Expected Instances: $($Global:ClusterConfig.Instances)" -ForegroundColor $Colors.White
    Write-Host "  • Running Instances: $($runningInstances.Count)" -ForegroundColor $Colors.White
    Write-Host "  • Profile: $($Global:ClusterConfig.Profile)" -ForegroundColor $Colors.White
    Write-Host "  • Status: $($clusterState.Status)" -ForegroundColor $(
        if ($clusterState.Status -eq "RUNNING") { $Colors.Green } 
        elseif ($clusterState.Status -eq "STOPPED") { $Colors.Red }
        else { $Colors.Yellow }
    )
    
    if ($clusterState.LastStart) {
        $uptime = (Get-Date) - [DateTime]$clusterState.LastStart
        Write-Host "  • Uptime: $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" -ForegroundColor $Colors.White
    }
    
    Write-Host ""
    
    # Instance details
    if ($runningInstances.Count -gt 0) {
        Write-Info "Running Instances:"
        
        foreach ($instance in $runningInstances) {
            Write-Host "  🌐 Port $($instance.Port):" -ForegroundColor $Colors.Blue
            Write-Host "    📊 Status: $($instance.Status)" -ForegroundColor $(
                if ($instance.Status -eq "UP") { $Colors.Green } else { $Colors.Yellow }
            )
            
            if ($instance.Health.components.hazelcast) {
                $hzStatus = $instance.Health.components.hazelcast.status
                Write-Host "    ⚡ Hazelcast: $hzStatus" -ForegroundColor $(
                    if ($hzStatus -eq "UP") { $Colors.Green } else { $Colors.Yellow }
                )
            }
            
            if ($instance.Health.components.db) {
                $dbStatus = $instance.Health.components.db.status
                Write-Host "    🗄️ Database: $dbStatus" -ForegroundColor $(
                    if ($dbStatus -eq "UP") { $Colors.Green } else { $Colors.Yellow }
                )
            }
            
            if ($instance.Process) {
                $runtime = if ($instance.Process.StartTime) { 
                    $elapsed = (Get-Date) - $instance.Process.StartTime
                    "$($elapsed.Hours)h $($elapsed.Minutes)m $($elapsed.Seconds)s"
                } else { "Unknown" }
                Write-Host "    🖥️ PID: $($instance.Process.Id) | Memory: $($instance.Process.Memory)MB | Runtime: $runtime" -ForegroundColor $Colors.Gray
            }
            
            Write-Host "    🌐 Application: http://localhost:$($instance.Port)" -ForegroundColor $Colors.Gray
            Write-Host ""
        }
        
        # Cluster information
        if ($runningInstances.Count -gt 1) {
            Show-HazelcastClusterInfo
        }
        
        # Common endpoints
        Write-Info "🌐 Common Endpoints:"
        $firstPort = $runningInstances[0].Port
        Write-Host "  • Swagger UI: http://localhost:$firstPort/swagger-ui.html" -ForegroundColor $Colors.White
        Write-Host "  • H2 Console: http://localhost:$firstPort/h2-console" -ForegroundColor $Colors.White
        Write-Host "  • Metrics: http://localhost:$firstPort/actuator/metrics" -ForegroundColor $Colors.White
        
    } else {
        Write-Info "No instances are currently running"
        Write-Host ""
        Write-Info "To start the cluster:"
        Write-Host "  .\scripts\development\cluster-manager.ps1 start" -ForegroundColor $Colors.Yellow
    }
    
    Write-Host ""
}

function Show-HazelcastClusterInfo {
    <#
    .SYNOPSIS
    Shows Hazelcast cluster information
    #>
    
    Write-Info "🔗 Hazelcast Cluster Information:"
    
    try {
        $runningInstances = Get-RunningInstances
        if ($runningInstances.Count -gt 0) {
            $firstPort = $runningInstances[0].Port
            $clusterResponse = Invoke-WebRequest -Uri "http://localhost:$firstPort/actuator/hazelcast" -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
            
            if ($clusterResponse) {
                $clusterInfo = $clusterResponse.Content | ConvertFrom-Json
                
                if ($clusterInfo.members) {
                    Write-Success "  🌐 Cluster Members: $($clusterInfo.members.Count)"
                    foreach ($member in $clusterInfo.members) {
                        $memberInfo = if ($member.localMember) {
                            "$($member.address) (local)"
                        } else {
                            $member.address
                        }
                        Write-Host "    🔹 $memberInfo" -ForegroundColor $Colors.White
                    }
                    
                    if ($clusterInfo.caches) {
                        Write-Info "  💾 Active Caches: $($clusterInfo.caches.Count)"
                        foreach ($cache in $clusterInfo.caches) {
                            Write-Host "    📦 $($cache.name): $($cache.size) entries" -ForegroundColor $Colors.White
                        }
                    }
                } else {
                    Write-Warning "  Cluster information not available"
                }
            } else {
                Write-Warning "  Could not retrieve cluster information"
            }
        }
    } catch {
        Write-Warning "  Error retrieving cluster information: $($_.Exception.Message)"
    }
}

function Test-ClusterFunctionality {
    <#
    .SYNOPSIS
    Tests cluster functionality with cache sharing
    #>
    
    Write-Host ""
    Write-Host "🧪 Testing Cluster Functionality" -ForegroundColor $Colors.Blue
    Write-Host "================================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    $runningInstances = Get-RunningInstances
    
    if ($runningInstances.Count -lt 2) {
        Write-Warning "Need at least 2 instances for cluster testing (found $($runningInstances.Count))"
        return $false
    }
    
    try {
        $port1 = $runningInstances[0].Port
        $port2 = $runningInstances[1].Port
        
        Write-Info "Testing cache distribution between instances..."
        Write-Host "  • Instance 1: Port $port1" -ForegroundColor $Colors.White
        Write-Host "  • Instance 2: Port $port2" -ForegroundColor $Colors.White
        Write-Host ""
        
        # Create user on first instance
        Write-Info "🔄 Creating user on instance 1..."
        $createBody = @{ 
            name = "Cluster Test User $(Get-Date -Format 'HHmmss')"
            email = "cluster.test.$(Get-Date -Format 'HHmmss')@example.com"
        } | ConvertTo-Json
        
        $createResponse = Invoke-WebRequest -Uri "http://localhost:$port1/api/users" -Method POST -Body $createBody -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
        $createdUser = $createResponse.Content | ConvertFrom-Json
        
        if ($createdUser.id) {
            Write-Success "✅ User created on instance 1: ID $($createdUser.id) - $($createdUser.name)"
            
            # Wait for cache synchronization
            Write-Info "⏳ Waiting for cache synchronization..."
            Start-Sleep 3
            
            # Try to retrieve from second instance
            Write-Info "🔍 Retrieving user from instance 2..."
            $getResponse = Invoke-WebRequest -Uri "http://localhost:$port2/api/users/$($createdUser.id)" -UseBasicParsing -TimeoutSec 10
            $retrievedUser = $getResponse.Content | ConvertFrom-Json
            
            if ($retrievedUser.name -eq $createdUser.name) {
                Write-Success "✅ CLUSTER TEST PASSED! 🎉"
                Write-Success "✅ Data successfully shared between cluster instances!"
                Write-Host ""
                Write-Info "Cache performance test..."
                
                # Performance test
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                for ($i = 1; $i -le 10; $i++) {
                    $testPort = $runningInstances[($i % $runningInstances.Count)].Port
                    Invoke-WebRequest -Uri "http://localhost:$testPort/api/users/$($createdUser.id)" -UseBasicParsing -TimeoutSec 5 | Out-Null
                }
                $sw.Stop()
                
                Write-Success "⚡ Performance: 10 distributed requests in $($sw.ElapsedMilliseconds)ms"
                Write-Success "✅ Hazelcast distributed cache is working correctly!"
                
                return $true
            } else {
                Write-Error "❌ Data not properly synchronized between instances"
                Write-Warning "Created: $($createdUser.name)"
                Write-Warning "Retrieved: $($retrievedUser.name)"
                return $false
            }
        } else {
            Write-Error "❌ Failed to create user on instance 1"
            return $false
        }
        
    } catch {
        Write-Error "❌ Cluster functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

function Set-ClusterScale {
    <#
    .SYNOPSIS
    Scales cluster to specified number of instances
    #>
    
    Write-Host ""
    Write-Host "📈 Scaling Hazelcast Local Cluster" -ForegroundColor $Colors.Blue
    Write-Host "===================================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    $currentInstances = Get-RunningInstances
    $currentCount = $currentInstances.Count
    $targetCount = $Global:ClusterConfig.Instances
    
    Write-Info "Scaling cluster from $currentCount to $targetCount instances..."
    
    if ($targetCount -eq $currentCount) {
        Write-Info "Cluster already has $targetCount instances"
        return $true
    } elseif ($targetCount -gt $currentCount) {
        Write-Info "Scaling up by $($targetCount - $currentCount) instances..."
        # TODO: Implement scale-up logic
        Write-Warning "Scale-up not implemented yet. Use restart for now."
        return Restart-ClusterInstances
    } else {
        Write-Info "Scaling down by $($currentCount - $targetCount) instances..."
        # TODO: Implement scale-down logic
        Write-Warning "Scale-down not implemented yet. Use restart for now."
        return Restart-ClusterInstances
    }
}

function Show-ClusterLogs {
    <#
    .SYNOPSIS
    Shows cluster logs
    #>
    
    Write-Host ""
    Write-Host "📜 Cluster Logs" -ForegroundColor $Colors.Blue
    Write-Host "===============" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    $logsDir = $Global:ClusterConfig.LogsDirectory
    
    if (-not (Test-Path $logsDir)) {
        Write-Warning "Logs directory not found: $logsDir"
        return
    }
    
    $logFiles = Get-ChildItem $logsDir -Filter "*.log"
    
    if ($logFiles.Count -eq 0) {
        Write-Warning "No log files found in: $logsDir"
        return
    }
    
    Write-Info "Available log files:"
    foreach ($logFile in $logFiles) {
        $size = [math]::Round($logFile.Length / 1KB, 2)
        Write-Host "  📄 $($logFile.Name) (${size}KB)" -ForegroundColor $Colors.White
    }
    
    Write-Host ""
    Write-Info "To view logs:"
    foreach ($logFile in $logFiles) {
        Write-Host "  Get-Content '$($logFile.FullName)' -Tail 50" -ForegroundColor $Colors.Yellow
    }
}

function Clear-ClusterEnvironment {
    <#
    .SYNOPSIS
    Cleans up cluster environment
    #>
    
    Write-Host ""
    Write-Host "🧹 Cleaning Up Cluster Environment" -ForegroundColor $Colors.Yellow
    Write-Host "===================================" -ForegroundColor $Colors.Yellow
    Write-Host ""
    
    # Stop instances
    Stop-ClusterInstances
    
    # Clean state
    Clear-ClusterState
    
    # Clean logs if requested
    if ($Force) {
        $logsDir = $Global:ClusterConfig.LogsDirectory
        if (Test-Path $logsDir) {
            Remove-Item $logsDir -Recurse -Force
            Write-Success "✅ Cluster logs cleaned"
        }
    }
    
    Write-Success "✅ Cluster environment cleaned up"
}

# ========================================================================
# MAIN EXECUTION
# ========================================================================

function Invoke-ClusterManager {
    <#
    .SYNOPSIS
    Main cluster manager function
    #>
    
    Write-Host ""
    Write-Host "🔗 Hazelcast Demo - Local Cluster Manager" -ForegroundColor $Colors.White
    Write-Host "==========================================" -ForegroundColor $Colors.White
    Write-Host ""
    
    # Set verbose logging if requested
    if ($Verbose) {
        $Global:CurrentLogLevel = $LogLevels.DEBUG
    }
    
    # Update global config with parameters
    $Global:ClusterConfig.Instances = $Instances
    $Global:ClusterConfig.StartPort = $StartPort
    $Global:ClusterConfig.Profile = $Profile
    $Global:ClusterConfig.WaitTimeout = $WaitTimeout
    
    try {
        switch ($Action) {
            "start" {
                $result = Start-ClusterInstances
                exit $(if ($result) { 0 } else { 1 })
            }
            "stop" {
                $result = Stop-ClusterInstances
                exit $(if ($result) { 0 } else { 1 })
            }
            "restart" {
                $result = Restart-ClusterInstances
                exit $(if ($result) { 0 } else { 1 })
            }
            "status" {
                Show-ClusterStatus
                exit 0
            }
            "test" {
                $result = Test-ClusterFunctionality
                exit $(if ($result) { 0 } else { 1 })
            }
            "scale" {
                $result = Set-ClusterScale
                exit $(if ($result) { 0 } else { 1 })
            }
            "logs" {
                Show-ClusterLogs
                exit 0
            }
            "cleanup" {
                Clear-ClusterEnvironment
                exit 0
            }
            default {
                Write-Error "Unknown action: $Action"
                exit 1
            }
        }
    } catch {
        Write-Error "Cluster manager failed: $($_.Exception.Message)"
        exit 1
    }
}

# Execute main function
Invoke-ClusterManager
