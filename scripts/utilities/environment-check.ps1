# ========================================================================
# Environment Prerequisites Checker for Hazelcast Demo
# ========================================================================
# Comprehensive verification of all prerequisites for different environments
# Author: Antonio Galluzzi (antonio.galluzzi91@gmail.com)
# Version: 2.0.0
# ========================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod", "openshift-local", "cloud", "all")]
    [string]$Environment = "all",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "detailed", "comprehensive")]
    [string]$CheckLevel = "detailed",
    
    [Parameter(Mandatory=$false)]
    [switch]$Fix,
    
    [Parameter(Mandatory=$false)]
    [switch]$Export,
    
    [Parameter(Mandatory=$false)]
    [string]$ExportFile = "environment-check-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
)

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
# GLOBAL VARIABLES
# ========================================================================

$Global:CheckResults = @{
    Timestamp = Get-Date
    Environment = $Environment
    CheckLevel = $CheckLevel
    OverallStatus = "UNKNOWN"
    Categories = @{}
    Recommendations = @()
    Errors = @()
    Warnings = @()
}

# ========================================================================
# PREREQUISITE DEFINITIONS
# ========================================================================

$Global:Prerequisites = @{
    "dev" = @{
        Required = @("java", "maven", "powershell")
        Recommended = @("docker", "git", "curl")
        Optional = @("vscode", "postman")
    }
    "staging" = @{
        Required = @("java", "maven", "docker", "postgresql")
        Recommended = @("git", "curl", "jq")
        Optional = @("k9s", "helm")
    }
    "prod" = @{
        Required = @("java", "maven", "docker", "kubernetes", "postgresql")
        Recommended = @("git", "curl", "jq", "helm")
        Optional = @("k9s", "kubectx", "monitoring")
    }
    "openshift-local" = @{
        Required = @("java", "maven", "oc", "crc", "docker")
        Recommended = @("git", "curl", "jq")
        Optional = @("vscode", "postman")
    }
    "cloud" = @{
        Required = @("java", "maven", "docker", "kubernetes", "helm")
        Recommended = @("git", "curl", "jq", "terraform")
        Optional = @("k9s", "kubectx", "monitoring")
    }
}

# ========================================================================
# CHECK FUNCTIONS
# ========================================================================

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
    Checks PowerShell version and execution policy
    #>
    
    $category = "PowerShell"
    $results = @()
    
    Write-Info "🔍 Checking PowerShell environment..."
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    $minVersion = [Version]"5.1"
    
    if ($psVersion -ge $minVersion) {
        $results += @{
            Check = "PowerShell Version"
            Status = "PASS"
            Message = "PowerShell $psVersion (>= $minVersion required)"
            Details = @{
                Current = $psVersion.ToString()
                Required = $minVersion.ToString()
                Edition = $PSVersionTable.PSEdition
            }
        }
    } else {
        $results += @{
            Check = "PowerShell Version"
            Status = "FAIL"
            Message = "PowerShell $psVersion is too old (>= $minVersion required)"
            Details = @{
                Current = $psVersion.ToString()
                Required = $minVersion.ToString()
                Edition = $PSVersionTable.PSEdition
            }
            Recommendation = "Update to PowerShell 5.1 or later"
        }
    }
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy
    $allowedPolicies = @("RemoteSigned", "Unrestricted", "Bypass")
    
    if ($executionPolicy -in $allowedPolicies) {
        $results += @{
            Check = "Execution Policy"
            Status = "PASS"
            Message = "Execution policy: $executionPolicy"
            Details = @{
                Current = $executionPolicy
                Allowed = $allowedPolicies
            }
        }
    } else {
        $results += @{
            Check = "Execution Policy"
            Status = "WARN"
            Message = "Execution policy: $executionPolicy (may block script execution)"
            Details = @{
                Current = $executionPolicy
                Allowed = $allowedPolicies
            }
            Recommendation = "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        }
    }
    
    return @{
        Category = $category
        Results = $results
    }
}

function Test-JavaEnvironment {
    <#
    .SYNOPSIS
    Comprehensive Java environment check
    #>
    
    $category = "Java"
    $results = @()
    
    Write-Info "🔍 Checking Java environment..."
    
    # Check Java installation
    if (Test-Command "java") {
        try {
            $javaOutput = & java -version 2>&1
            $versionLine = $javaOutput | Where-Object { $_ -match "version" } | Select-Object -First 1
            
            if ($versionLine -match '"([^"]+)"') {
                $javaVersion = $matches[1]
                $majorVersion = [int]($javaVersion -split '\.')[0]
                $minVersion = 17
                
                if ($majorVersion -ge $minVersion) {
                    $results += @{
                        Check = "Java Version"
                        Status = "PASS"
                        Message = "Java $javaVersion (>= $minVersion required)"
                        Details = @{
                            Version = $javaVersion
                            MajorVersion = $majorVersion
                            MinRequired = $minVersion
                            FullOutput = $javaOutput -join "`n"
                        }
                    }
                } else {
                    $results += @{
                        Check = "Java Version"
                        Status = "FAIL"
                        Message = "Java $javaVersion is too old (>= $minVersion required)"
                        Details = @{
                            Version = $javaVersion
                            MajorVersion = $majorVersion
                            MinRequired = $minVersion
                        }
                        Recommendation = "Install Java $minVersion or later"
                    }
                }
            }
            
            # Check JAVA_HOME
            $javaHome = $env:JAVA_HOME
            if ($javaHome -and (Test-Path $javaHome)) {
                $results += @{
                    Check = "JAVA_HOME"
                    Status = "PASS"
                    Message = "JAVA_HOME set to: $javaHome"
                    Details = @{
                        Path = $javaHome
                        Exists = Test-Path $javaHome
                    }
                }
            } else {
                $results += @{
                    Check = "JAVA_HOME"
                    Status = "WARN"
                    Message = "JAVA_HOME not set or invalid"
                    Details = @{
                        Path = $javaHome
                        Exists = if ($javaHome) { Test-Path $javaHome } else { $false }
                    }
                    Recommendation = "Set JAVA_HOME environment variable"
                }
            }
            
        } catch {
            $results += @{
                Check = "Java Installation"
                Status = "FAIL"
                Message = "Java command failed: $($_.Exception.Message)"
                Recommendation = "Install Java 17 or later"
            }
        }
    } else {
        $results += @{
            Check = "Java Installation"
            Status = "FAIL"
            Message = "Java not found in PATH"
            Recommendation = "Install Java 17 or later and add to PATH"
        }
    }
    
    return @{
        Category = $category
        Results = $results
    }
}

function Test-MavenEnvironment {
    <#
    .SYNOPSIS
    Maven environment check
    #>
    
    $category = "Maven"
    $results = @()
    
    Write-Info "🔍 Checking Maven environment..."
    
    # Check Maven wrapper
    if (Test-Path ".\mvnw.cmd") {
        $results += @{
            Check = "Maven Wrapper"
            Status = "PASS"
            Message = "Maven wrapper found (mvnw.cmd)"
            Details = @{
                Path = (Resolve-Path ".\mvnw.cmd").Path
                Size = (Get-Item ".\mvnw.cmd").Length
            }
        }
    } else {
        $results += @{
            Check = "Maven Wrapper"
            Status = "FAIL"
            Message = "Maven wrapper not found (mvnw.cmd)"
            Recommendation = "Ensure you're in the project root directory"
        }
    }
    
    # Check system Maven
    if (Test-Command "mvn") {
        try {
            $mvnOutput = & mvn -version 2>&1
            $versionLine = $mvnOutput | Select-Object -First 1
            
            $results += @{
                Check = "System Maven"
                Status = "PASS"
                Message = "System Maven found: $versionLine"
                Details = @{
                    FullOutput = $mvnOutput -join "`n"
                }
            }
        } catch {
            $results += @{
                Check = "System Maven"
                Status = "WARN"
                Message = "System Maven found but version check failed"
            }
        }
    } else {
        $results += @{
            Check = "System Maven"
            Status = "INFO"
            Message = "System Maven not found (wrapper available)"
        }
    }
    
    return @{
        Category = $category
        Results = $results
    }
}

function Test-DockerEnvironment {
    <#
    .SYNOPSIS
    Docker environment check
    #>
    
    $category = "Docker"
    $results = @()
    
    Write-Info "🔍 Checking Docker environment..."
    
    # Check Docker installation
    if (Test-Command "docker") {
        try {
            $dockerVersion = & docker --version 2>&1
            $results += @{
                Check = "Docker Installation"
                Status = "PASS"
                Message = "Docker found: $dockerVersion"
                Details = @{
                    Version = $dockerVersion
                }
            }
            
            # Check Docker daemon
            try {
                $dockerInfo = & docker info 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $results += @{
                        Check = "Docker Daemon"
                        Status = "PASS"
                        Message = "Docker daemon is running"
                        Details = @{
                            Info = $dockerInfo -join "`n"
                        }
                    }
                } else {
                    $results += @{
                        Check = "Docker Daemon"
                        Status = "FAIL"
                        Message = "Docker daemon is not running"
                        Recommendation = "Start Docker Desktop or Docker daemon"
                    }
                }
            } catch {
                $results += @{
                    Check = "Docker Daemon"
                    Status = "FAIL"
                    Message = "Cannot connect to Docker daemon"
                    Recommendation = "Start Docker Desktop or Docker daemon"
                }
            }
            
        } catch {
            $results += @{
                Check = "Docker Installation"
                Status = "FAIL"
                Message = "Docker command failed: $($_.Exception.Message)"
            }
        }
    } else {
        $results += @{
            Check = "Docker Installation"
            Status = "FAIL"
            Message = "Docker not found in PATH"
            Recommendation = "Install Docker Desktop"
        }
    }
    
    return @{
        Category = $category
        Results = $results
    }
}

function Test-OpenShiftEnvironment {
    <#
    .SYNOPSIS
    OpenShift environment check
    #>
    
    $category = "OpenShift"
    $results = @()
    
    Write-Info "🔍 Checking OpenShift environment..."
    
    # Check OpenShift CLI
    if (Test-Command "oc") {
        try {
            $ocVersion = & oc version --client=true 2>&1
            $results += @{
                Check = "OpenShift CLI"
                Status = "PASS"
                Message = "OpenShift CLI found"
                Details = @{
                    Version = $ocVersion -join "`n"
                }
            }
            
            # Check cluster connection
            try {
                $server = & oc whoami --show-server 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $user = & oc whoami 2>&1
                    $results += @{
                        Check = "Cluster Connection"
                        Status = "PASS"
                        Message = "Connected to $server as $user"
                        Details = @{
                            Server = $server
                            User = $user
                        }
                    }
                } else {
                    $results += @{
                        Check = "Cluster Connection"
                        Status = "WARN"
                        Message = "Not connected to any cluster"
                        Recommendation = "Login to OpenShift cluster with 'oc login'"
                    }
                }
            } catch {
                $results += @{
                    Check = "Cluster Connection"
                    Status = "WARN"
                    Message = "Cannot check cluster connection"
                }
            }
            
        } catch {
            $results += @{
                Check = "OpenShift CLI"
                Status = "FAIL"
                Message = "OpenShift CLI command failed"
            }
        }
    } else {
        $results += @{
            Check = "OpenShift CLI"
            Status = "FAIL"
            Message = "OpenShift CLI (oc) not found in PATH"
            Recommendation = "Install OpenShift CLI from https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
        }
    }
    
    # Check CRC (OpenShift Local)
    if (Test-Command "crc") {
        try {
            $crcVersion = & crc version 2>&1
            $results += @{
                Check = "CRC (OpenShift Local)"
                Status = "PASS"
                Message = "CRC found"
                Details = @{
                    Version = $crcVersion -join "`n"
                }
            }
            
            # Check CRC status
            try {
                $crcStatus = & crc status 2>&1
                $results += @{
                    Check = "CRC Status"
                    Status = "INFO"
                    Message = "CRC status checked"
                    Details = @{
                        Status = $crcStatus -join "`n"
                    }
                }
            } catch {
                $results += @{
                    Check = "CRC Status"
                    Status = "WARN"
                    Message = "Cannot check CRC status"
                }
            }
            
        } catch {
            $results += @{
                Check = "CRC (OpenShift Local)"
                Status = "FAIL"
                Message = "CRC command failed"
            }
        }
    } else {
        $results += @{
            Check = "CRC (OpenShift Local)"
            Status = "FAIL"
            Message = "CRC not found in PATH"
            Recommendation = "Install OpenShift Local from https://console.redhat.com/openshift/create/local"
        }
    }
    
    return @{
        Category = $category
        Results = $results
    }
}

function Test-GitEnvironment {
    <#
    .SYNOPSIS
    Git environment check
    #>
    
    $category = "Git"
    $results = @()
    
    Write-Info "🔍 Checking Git environment..."
    
    if (Test-Command "git") {
        try {
            $gitVersion = & git --version 2>&1
            $results += @{
                Check = "Git Installation"
                Status = "PASS"
                Message = "Git found: $gitVersion"
                Details = @{
                    Version = $gitVersion
                }
            }
            
            # Check Git configuration
            try {
                $gitUser = & git config --global user.name 2>&1
                $gitEmail = & git config --global user.email 2>&1
                
                if ($gitUser -and $gitEmail) {
                    $results += @{
                        Check = "Git Configuration"
                        Status = "PASS"
                        Message = "Git configured for $gitUser <$gitEmail>"
                        Details = @{
                            User = $gitUser
                            Email = $gitEmail
                        }
                    }
                } else {
                    $results += @{
                        Check = "Git Configuration"
                        Status = "WARN"
                        Message = "Git user or email not configured"
                        Recommendation = "Configure with: git config --global user.name 'Your Name' && git config --global user.email 'your@email.com'"
                    }
                }
            } catch {
                $results += @{
                    Check = "Git Configuration"
                    Status = "WARN"
                    Message = "Cannot check Git configuration"
                }
            }
            
        } catch {
            $results += @{
                Check = "Git Installation"
                Status = "FAIL"
                Message = "Git command failed"
            }
        }
    } else {
        $results += @{
            Check = "Git Installation"
            Status = "FAIL"
            Message = "Git not found in PATH"
            Recommendation = "Install Git from https://git-scm.com/"
        }
    }
    
    return @{
        Category = $category
        Results = $results
    }
}

function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
    Network connectivity check
    #>
    
    $category = "Network"
    $results = @()
    
    Write-Info "🔍 Checking network connectivity..."
    
    $testUrls = @(
        @{ Name = "Maven Central"; Url = "https://repo1.maven.org/maven2/" }
        @{ Name = "Docker Hub"; Url = "https://registry-1.docker.io/" }
        @{ Name = "GitHub"; Url = "https://github.com" }
        @{ Name = "Red Hat Registry"; Url = "https://registry.redhat.io/" }
    )
    
    foreach ($test in $testUrls) {
        try {
            $response = Invoke-WebRequest -Uri $test.Url -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            $results += @{
                Check = "$($test.Name) Connectivity"
                Status = "PASS"
                Message = "$($test.Name) is reachable (HTTP $($response.StatusCode))"
                Details = @{
                    Url = $test.Url
                    StatusCode = $response.StatusCode
                    ResponseTime = "< 10s"
                }
            }
        } catch {
            $results += @{
                Check = "$($test.Name) Connectivity"
                Status = "WARN"
                Message = "$($test.Name) is not reachable: $($_.Exception.Message)"
                Details = @{
                    Url = $test.Url
                    Error = $_.Exception.Message
                }
                Recommendation = "Check internet connection and firewall settings"
            }
        }
    }
    
    return @{
        Category = $category
        Results = $results
    }
}

function Test-SystemResources {
    <#
    .SYNOPSIS
    System resources check
    #>
    
    $category = "System Resources"
    $results = @()
    
    Write-Info "🔍 Checking system resources..."
    
    # Check memory
    $memory = Get-CimInstance -ClassName Win32_ComputerSystem
    $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
    $minMemoryGB = 8
    
    if ($totalMemoryGB -ge $minMemoryGB) {
        $results += @{
            Check = "System Memory"
            Status = "PASS"
            Message = "${totalMemoryGB}GB RAM available (>= ${minMemoryGB}GB recommended)"
            Details = @{
                TotalGB = $totalMemoryGB
                MinRecommendedGB = $minMemoryGB
            }
        }
    } else {
        $results += @{
            Check = "System Memory"
            Status = "WARN"
            Message = "${totalMemoryGB}GB RAM (< ${minMemoryGB}GB recommended)"
            Details = @{
                TotalGB = $totalMemoryGB
                MinRecommendedGB = $minMemoryGB
            }
            Recommendation = "Consider upgrading to at least ${minMemoryGB}GB RAM for optimal performance"
        }
    }
    
    # Check disk space
    $drive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object DeviceID -eq "C:"
    $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    $minFreeSpaceGB = 10
    
    if ($freeSpaceGB -ge $minFreeSpaceGB) {
        $results += @{
            Check = "Disk Space"
            Status = "PASS"
            Message = "${freeSpaceGB}GB free space (>= ${minFreeSpaceGB}GB recommended)"
            Details = @{
                FreeSpaceGB = $freeSpaceGB
                MinRecommendedGB = $minFreeSpaceGB
            }
        }
    } else {
        $results += @{
            Check = "Disk Space"
            Status = "WARN"
            Message = "${freeSpaceGB}GB free space (< ${minFreeSpaceGB}GB recommended)"
            Details = @{
                FreeSpaceGB = $freeSpaceGB
                MinRecommendedGB = $minFreeSpaceGB
            }
            Recommendation = "Free up disk space for optimal performance"
        }
    }
    
    # Check CPU cores
    $cpu = Get-CimInstance -ClassName Win32_Processor
    $coreCount = $cpu.NumberOfCores
    $minCores = 4
    
    if ($coreCount -ge $minCores) {
        $results += @{
            Check = "CPU Cores"
            Status = "PASS"
            Message = "$coreCount CPU cores (>= $minCores recommended)"
            Details = @{
                Cores = $coreCount
                MinRecommended = $minCores
                ProcessorName = $cpu.Name
            }
        }
    } else {
        $results += @{
            Check = "CPU Cores"
            Status = "WARN"
            Message = "$coreCount CPU cores (< $minCores recommended)"
            Details = @{
                Cores = $coreCount
                MinRecommended = $minCores
                ProcessorName = $cpu.Name
            }
            Recommendation = "Consider upgrading to at least $minCores CPU cores"
        }
    }
    
    return @{
        Category = $category
        Results = $results
    }
}

# ========================================================================
# MAIN EXECUTION FUNCTIONS
# ========================================================================

function Invoke-EnvironmentCheck {
    <#
    .SYNOPSIS
    Executes comprehensive environment check
    #>
    
    Write-Host ""
    Write-Host "🔍 Hazelcast Demo - Environment Prerequisites Check" -ForegroundColor $Colors.White
    Write-Host "===================================================" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Info "Environment: $Environment"
    Write-Info "Check Level: $CheckLevel"
    Write-Host ""
    
    # Define checks to run based on environment and level
    $checksToRun = @()
    
    # Always run basic checks
    $checksToRun += "PowerShell", "Java", "Maven"
    
    # Add environment-specific checks
    switch ($Environment) {
        "dev" {
            if ($CheckLevel -in @("detailed", "comprehensive")) {
                $checksToRun += "Git", "SystemResources"
            }
            if ($CheckLevel -eq "comprehensive") {
                $checksToRun += "Docker", "Network"
            }
        }
        "openshift-local" {
            $checksToRun += "OpenShift", "Docker"
            if ($CheckLevel -in @("detailed", "comprehensive")) {
                $checksToRun += "Git", "SystemResources"
            }
            if ($CheckLevel -eq "comprehensive") {
                $checksToRun += "Network"
            }
        }
        { $_ -in @("staging", "prod", "cloud") } {
            $checksToRun += "Docker"
            if ($CheckLevel -in @("detailed", "comprehensive")) {
                $checksToRun += "Git", "SystemResources"
            }
            if ($CheckLevel -eq "comprehensive") {
                $checksToRun += "Network"
            }
        }
        "all" {
            $checksToRun += "OpenShift", "Docker", "Git", "SystemResources"
            if ($CheckLevel -eq "comprehensive") {
                $checksToRun += "Network"
            }
        }
    }
    
    # Execute checks
    $checkFunctions = @{
        "PowerShell" = "Test-PowerShellVersion"
        "Java" = "Test-JavaEnvironment"
        "Maven" = "Test-MavenEnvironment"
        "Docker" = "Test-DockerEnvironment"
        "OpenShift" = "Test-OpenShiftEnvironment"
        "Git" = "Test-GitEnvironment"
        "Network" = "Test-NetworkConnectivity"
        "SystemResources" = "Test-SystemResources"
    }
    
    $allPassed = $true
    $allChecks = @()
    
    foreach ($checkName in $checksToRun) {
        $functionName = $checkFunctions[$checkName]
        if ($functionName) {
            try {
                $checkResult = & $functionName
                $Global:CheckResults.Categories[$checkResult.Category] = $checkResult.Results
                $allChecks += $checkResult.Results
                
                # Check for failures
                $failures = @($checkResult.Results | Where-Object { $_.Status -eq "FAIL" })
                $failureCount = $failures.Count
                if ($failureCount -gt 0) {
                    $allPassed = $false
                }
            } catch {
                Write-Error "Failed to run check $checkName`: $($_.Exception.Message)"
                $allPassed = $false
            }
        }
    }
    
    # Generate summary
    Show-CheckSummary -AllChecks $allChecks -AllPassed $allPassed
    
    # Export results if requested
    if ($Export) {
        Export-CheckResults -AllChecks $allChecks
    }
    
    $Global:CheckResults.OverallStatus = if ($allPassed) { "PASS" } else { "FAIL" }
    
    return $allPassed
}

function Show-CheckSummary {
    <#
    .SYNOPSIS
    Shows summary of all checks
    #>
    param($AllChecks, $AllPassed)
    
    Write-Host ""
    Write-Host "📊 Prerequisites Check Summary" -ForegroundColor $Colors.White
    Write-Host "==============================" -ForegroundColor $Colors.White
    Write-Host ""
    
    # Count results by status
    $statusCounts = @{}
    $AllChecks | ForEach-Object {
        $status = $_.Status
        if (-not $statusCounts.ContainsKey($status)) {
            $statusCounts[$status] = 0
        }
        $statusCounts[$status]++
    }
    
    # Show status summary
    foreach ($status in @("PASS", "WARN", "FAIL", "INFO")) {
        $count = $statusCounts[$status]
        if ($count -gt 0) {
            $color = switch ($status) {
                "PASS" { $Colors.Green }
                "WARN" { $Colors.Yellow }
                "FAIL" { $Colors.Red }
                "INFO" { $Colors.Blue }
            }
            Write-Host "  $status`: $count" -ForegroundColor $color
        }
    }
    
    Write-Host ""
    
    # Show detailed results grouped by category
    foreach ($category in ($Global:CheckResults.Categories.Keys | Sort-Object)) {
        $categoryResults = $Global:CheckResults.Categories[$category]
        
        Write-Host "📁 $category" -ForegroundColor $Colors.Blue
        foreach ($result in $categoryResults) {
            $icon = switch ($result.Status) {
                "PASS" { "✅" }
                "WARN" { "⚠️" }
                "FAIL" { "❌" }
                "INFO" { "ℹ️" }
            }
            
            $color = switch ($result.Status) {
                "PASS" { $Colors.Green }
                "WARN" { $Colors.Yellow }
                "FAIL" { $Colors.Red }
                "INFO" { $Colors.Blue }
            }
            
            Write-Host "  $icon $($result.Check): $($result.Message)" -ForegroundColor $color
            
            if ($result.Recommendation) {
                Write-Host "    💡 $($result.Recommendation)" -ForegroundColor $Colors.Gray
            }
        }
        Write-Host ""
    }
    
    # Overall result
    if ($AllPassed) {
        Write-Host "🎉 All prerequisites checks PASSED! 🎉" -ForegroundColor $Colors.Green
    } else {
        Write-Host "⚠️ Some prerequisites checks FAILED or have WARNINGS" -ForegroundColor $Colors.Yellow
        Write-Host "Please review the recommendations above" -ForegroundColor $Colors.Yellow
    }
    
    Write-Host ""
}

function Export-CheckResults {
    <#
    .SYNOPSIS
    Exports check results to JSON file
    #>
    param($AllChecks)
    
    Write-Info "📄 Exporting results to: $ExportFile"
    
    $Global:CheckResults.Checks = $AllChecks
    $Global:CheckResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportFile -Encoding UTF8
    
    Write-Success "Results exported to: $ExportFile"
}

# ========================================================================
# MAIN EXECUTION
# ========================================================================

# Main execution
try {
    $checksPassed = Invoke-EnvironmentCheck
    
    if ($checksPassed) {
        exit 0
    } else {
        exit 1
    }
} catch {
    Write-Error "Environment check failed: $($_.Exception.Message)"
    exit 1
}
