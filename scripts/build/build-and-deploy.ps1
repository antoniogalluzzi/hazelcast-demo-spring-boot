# ========================================================================
# Build and Deploy Script for Hazelcast Demo
# ========================================================================
# Comprehensive build, test, and deployment automation
# Author: Antonio Galluzzi (antonio.galluzzi91@gmail.com)
# Version: 2.0.0
# ========================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("build", "test", "package", "deploy", "all")]
    [string]$Action = "all",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod", "openshift-local", "cloud")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("local", "docker", "openshift", "kubernetes")]
    [string]$Target = "local",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests,
    
    [Parameter(Mandatory=$false)]
    [switch]$Clean,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipLinting,
    
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "latest",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "hazelcast-demo",
    
    [Parameter(Mandatory=$false)]
    [switch]$Push,
    
    [Parameter(Mandatory=$false)]
    [string]$Registry = "localhost:5000",
    
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

$Global:BuildConfig = @{
    Action = $Action
    Environment = $Environment
    Target = $Target
    ImageTag = $ImageTag
    Namespace = $Namespace
    Registry = $Registry
    SkipTests = $SkipTests
    Clean = $Clean
    SkipLinting = $SkipLinting
    Push = $Push
    ProjectRoot = Get-ProjectRoot
    BuildInfo = @{
        StartTime = Get-Date
        EndTime = $null
        Version = $null
        GitCommit = $null
        Branch = $null
        Success = $false
        Artifacts = @()
    }
}

# ========================================================================
# BUILD INFORMATION FUNCTIONS
# ========================================================================

function Get-BuildInformation {
    <#
    .SYNOPSIS
    Collects build information from Git and project
    #>
    
    Write-Info "Collecting build information..."
    
    Push-Location $Global:BuildConfig.ProjectRoot
    
    try {
        # Get version from Maven
        $pomVersion = & ./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout 2>$null
        if ($pomVersion) {
            $Global:BuildConfig.BuildInfo.Version = $pomVersion.Trim()
        }
        
        # Get Git information
        $gitCommit = & git rev-parse HEAD 2>$null
        if ($gitCommit) {
            $Global:BuildConfig.BuildInfo.GitCommit = $gitCommit.Trim()
        }
        
        $gitBranch = & git rev-parse --abbrev-ref HEAD 2>$null
        if ($gitBranch) {
            $Global:BuildConfig.BuildInfo.Branch = $gitBranch.Trim()
        }
        
        Write-Success "✅ Build information collected"
        Write-Host "   Version: $($Global:BuildConfig.BuildInfo.Version)" -ForegroundColor $Colors.Gray
        Write-Host "   Branch: $($Global:BuildConfig.BuildInfo.Branch)" -ForegroundColor $Colors.Gray
        Write-Host "   Commit: $($Global:BuildConfig.BuildInfo.GitCommit.Substring(0, 8))" -ForegroundColor $Colors.Gray
        
    } catch {
        Write-Warning "⚠️ Could not collect all build information: $($_.Exception.Message)"
        
    } finally {
        Pop-Location
    }
}

function Set-BuildEnvironment {
    <#
    .SYNOPSIS
    Sets up build environment variables
    #>
    
    Write-Info "Setting up build environment for: $($Global:BuildConfig.Environment)"
    
    # Set Maven profile
    $env:MAVEN_OPTS = "-Xmx2g -XX:MaxMetaspaceSize=512m"
    
    # Set environment-specific variables
    switch ($Global:BuildConfig.Environment) {
        "dev" {
            $env:SPRING_PROFILES_ACTIVE = "dev"
        }
        "staging" {
            $env:SPRING_PROFILES_ACTIVE = "staging"
        }
        "prod" {
            $env:SPRING_PROFILES_ACTIVE = "prod"
        }
        "openshift-local" {
            $env:SPRING_PROFILES_ACTIVE = "openshift-local"
        }
        "cloud" {
            $env:SPRING_PROFILES_ACTIVE = "cloud"
        }
    }
    
    # Set build metadata
    if ($Global:BuildConfig.BuildInfo.Version) {
        $env:BUILD_VERSION = $Global:BuildConfig.BuildInfo.Version
    }
    
    if ($Global:BuildConfig.BuildInfo.GitCommit) {
        $env:BUILD_COMMIT = $Global:BuildConfig.BuildInfo.GitCommit
    }
    
    if ($Global:BuildConfig.BuildInfo.Branch) {
        $env:BUILD_BRANCH = $Global:BuildConfig.BuildInfo.Branch
    }
    
    $env:BUILD_TIMESTAMP = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    Write-Success "✅ Build environment configured"
}

# ========================================================================
# BUILD FUNCTIONS
# ========================================================================

function Invoke-ProjectBuild {
    <#
    .SYNOPSIS
    Builds the project with Maven
    #>
    
    Write-Host ""
    Write-Host "🏗️ Building Project" -ForegroundColor $Colors.Blue
    Write-Host "===================" -ForegroundColor $Colors.Blue
    
    Push-Location $Global:BuildConfig.ProjectRoot
    
    try {
        # Prepare Maven command
        $mavenArgs = @()
        
        if ($Global:BuildConfig.Clean) {
            $mavenArgs += "clean"
        }
        
        $mavenArgs += "compile"
        
        # Add environment profile
        $mavenArgs += "-P$($Global:BuildConfig.Environment)"
        
        # Add verbose if requested
        if ($Verbose) {
            $mavenArgs += "-X"
        } else {
            $mavenArgs += "-q"
        }
        
        Write-Info "Running Maven build..."
        Write-Debug "Maven command: ./mvnw $($mavenArgs -join ' ')"
        
        $buildStartTime = Get-Date
        
        & ./mvnw @mavenArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Maven build failed with exit code $LASTEXITCODE"
        }
        
        $buildEndTime = Get-Date
        $buildDuration = $buildEndTime - $buildStartTime
        
        Write-Success "✅ Project build completed in $($buildDuration.Minutes)m $($buildDuration.Seconds)s"
        
        # Check for build artifacts
        $targetDir = Join-Path $Global:BuildConfig.ProjectRoot "target"
        if (Test-Path $targetDir) {
            $jarFiles = Get-ChildItem $targetDir -Filter "*.jar" | Where-Object { $_.Name -notlike "*sources*" -and $_.Name -notlike "*javadoc*" }
            foreach ($jar in $jarFiles) {
                $Global:BuildConfig.BuildInfo.Artifacts += $jar.FullName
                Write-Host "   📦 Artifact: $($jar.Name)" -ForegroundColor $Colors.Gray
            }
        }
        
        return $true
        
    } catch {
        Write-Error "❌ Build failed: $($_.Exception.Message)"
        return $false
        
    } finally {
        Pop-Location
    }
}

function Invoke-ProjectTests {
    <#
    .SYNOPSIS
    Runs project tests
    #>
    
    if ($Global:BuildConfig.SkipTests) {
        Write-Info "Skipping tests (--SkipTests specified)"
        return $true
    }
    
    Write-Host ""
    Write-Host "🧪 Running Tests" -ForegroundColor $Colors.Blue
    Write-Host "================" -ForegroundColor $Colors.Blue
    
    Push-Location $Global:BuildConfig.ProjectRoot
    
    try {
        # Prepare Maven test command
        $testArgs = @("test")
        
        # Add environment profile
        $testArgs += "-P$($Global:BuildConfig.Environment)"
        
        # Add verbose if requested
        if ($Verbose) {
            $testArgs += "-X"
        }
        
        Write-Info "Running unit tests..."
        
        $testStartTime = Get-Date
        
        & ./mvnw @testArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Tests failed with exit code $LASTEXITCODE"
        }
        
        $testEndTime = Get-Date
        $testDuration = $testEndTime - $testStartTime
        
        Write-Success "✅ Tests completed in $($testDuration.Minutes)m $($testDuration.Seconds)s"
        
        # Show test report summary
        $surefireReports = Join-Path $Global:BuildConfig.ProjectRoot "target\surefire-reports"
        if (Test-Path $surefireReports) {
            $testXml = Get-ChildItem $surefireReports -Filter "TEST-*.xml" | Select-Object -First 1
            if ($testXml) {
                try {
                    [xml]$testResults = Get-Content $testXml.FullName
                    $testSuite = $testResults.testsuite
                    
                    Write-Host "   📊 Test Results:" -ForegroundColor $Colors.Gray
                    Write-Host "      Tests: $($testSuite.tests)" -ForegroundColor $Colors.Gray
                    Write-Host "      Failures: $($testSuite.failures)" -ForegroundColor $(if ($testSuite.failures -eq 0) { $Colors.Green } else { $Colors.Red })
                    Write-Host "      Errors: $($testSuite.errors)" -ForegroundColor $(if ($testSuite.errors -eq 0) { $Colors.Green } else { $Colors.Red })
                    Write-Host "      Skipped: $($testSuite.skipped)" -ForegroundColor $Colors.Gray
                    
                } catch {
                    Write-Debug "Could not parse test results: $($_.Exception.Message)"
                }
            }
        }
        
        return $true
        
    } catch {
        Write-Error "❌ Tests failed: $($_.Exception.Message)"
        return $false
        
    } finally {
        Pop-Location
    }
}

function Invoke-ProjectPackage {
    <#
    .SYNOPSIS
    Packages the project
    #>
    
    Write-Host ""
    Write-Host "📦 Packaging Project" -ForegroundColor $Colors.Blue
    Write-Host "===================" -ForegroundColor $Colors.Blue
    
    Push-Location $Global:BuildConfig.ProjectRoot
    
    try {
        # Prepare Maven package command
        $packageArgs = @("package")
        
        # Add environment profile
        $packageArgs += "-P$($Global:BuildConfig.Environment)"
        
        # Skip tests if already run or explicitly skipped
        if ($Global:BuildConfig.SkipTests) {
            $packageArgs += "-DskipTests"
        }
        
        # Add verbose if requested
        if ($Verbose) {
            $packageArgs += "-X"
        } else {
            $packageArgs += "-q"
        }
        
        Write-Info "Creating application package..."
        
        $packageStartTime = Get-Date
        
        & ./mvnw @packageArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Packaging failed with exit code $LASTEXITCODE"
        }
        
        $packageEndTime = Get-Date
        $packageDuration = $packageEndTime - $packageStartTime
        
        Write-Success "✅ Packaging completed in $($packageDuration.Minutes)m $($packageDuration.Seconds)s"
        
        # Update artifacts list
        $targetDir = Join-Path $Global:BuildConfig.ProjectRoot "target"
        if (Test-Path $targetDir) {
            $jarFiles = Get-ChildItem $targetDir -Filter "*.jar" | Where-Object { $_.Name -notlike "*sources*" -and $_.Name -notlike "*javadoc*" }
            foreach ($jar in $jarFiles) {
                if ($jar.FullName -notin $Global:BuildConfig.BuildInfo.Artifacts) {
                    $Global:BuildConfig.BuildInfo.Artifacts += $jar.FullName
                }
                Write-Host "   📦 Package: $($jar.Name) ($([math]::Round($jar.Length / 1MB, 2)) MB)" -ForegroundColor $Colors.Gray
            }
        }
        
        return $true
        
    } catch {
        Write-Error "❌ Packaging failed: $($_.Exception.Message)"
        return $false
        
    } finally {
        Pop-Location
    }
}

# ========================================================================
# CONTAINER FUNCTIONS
# ========================================================================

function Build-ContainerImage {
    <#
    .SYNOPSIS
    Builds container image
    #>
    
    if ($Global:BuildConfig.Target -eq "local") {
        Write-Info "Skipping container build for local target"
        return $true
    }
    
    Write-Host ""
    Write-Host "🐳 Building Container Image" -ForegroundColor $Colors.Blue
    Write-Host "==========================" -ForegroundColor $Colors.Blue
    
    Push-Location $Global:BuildConfig.ProjectRoot
    
    try {
        # Check if Dockerfile exists
        $dockerFile = Join-Path $Global:BuildConfig.ProjectRoot "Dockerfile"
        if (-not (Test-Path $dockerFile)) {
            throw "Dockerfile not found at $dockerFile"
        }
        
        # Prepare image name
        $imageName = "hazelcast-demo"
        $fullImageName = "${imageName}:$($Global:BuildConfig.ImageTag)"
        
        if ($Global:BuildConfig.Registry -and $Global:BuildConfig.Registry -ne "localhost:5000") {
            $fullImageName = "$($Global:BuildConfig.Registry)/${fullImageName}"
        }
        
        Write-Info "Building container image: $fullImageName"
        
        # Build arguments
        $buildArgs = @(
            "build"
            "-t", $fullImageName
            "--build-arg", "SPRING_PROFILES_ACTIVE=$($Global:BuildConfig.Environment)"
        )
        
        if ($Global:BuildConfig.BuildInfo.Version) {
            $buildArgs += "--build-arg", "BUILD_VERSION=$($Global:BuildConfig.BuildInfo.Version)"
        }
        
        if ($Global:BuildConfig.BuildInfo.GitCommit) {
            $buildArgs += "--build-arg", "BUILD_COMMIT=$($Global:BuildConfig.BuildInfo.GitCommit)"
        }
        
        $buildArgs += "."
        
        $containerStartTime = Get-Date
        
        & docker @buildArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Container build failed with exit code $LASTEXITCODE"
        }
        
        $containerEndTime = Get-Date
        $containerDuration = $containerEndTime - $containerStartTime
        
        Write-Success "✅ Container image built in $($containerDuration.Minutes)m $($containerDuration.Seconds)s"
        Write-Host "   🐳 Image: $fullImageName" -ForegroundColor $Colors.Gray
        
        # Get image size
        $imageInfo = & docker images $fullImageName --format "{{.Size}}" 2>$null
        if ($imageInfo) {
            Write-Host "   📏 Size: $imageInfo" -ForegroundColor $Colors.Gray
        }
        
        # Push if requested
        if ($Global:BuildConfig.Push) {
            Write-Info "Pushing container image..."
            
            & docker push $fullImageName
            
            if ($LASTEXITCODE -ne 0) {
                throw "Container push failed with exit code $LASTEXITCODE"
            }
            
            Write-Success "✅ Container image pushed"
        }
        
        return $true
        
    } catch {
        Write-Error "❌ Container build failed: $($_.Exception.Message)"
        return $false
        
    } finally {
        Pop-Location
    }
}

# ========================================================================
# DEPLOYMENT FUNCTIONS
# ========================================================================

function Deploy-Application {
    <#
    .SYNOPSIS
    Deploys application to target environment
    #>
    
    Write-Host ""
    Write-Host "🚀 Deploying Application" -ForegroundColor $Colors.Blue
    Write-Host "========================" -ForegroundColor $Colors.Blue
    
    switch ($Global:BuildConfig.Target) {
        "local" {
            return Deploy-Local
        }
        "docker" {
            return Deploy-Docker
        }
        "openshift" {
            return Deploy-OpenShift
        }
        "kubernetes" {
            return Deploy-Kubernetes
        }
        default {
            Write-Error "❌ Unknown deployment target: $($Global:BuildConfig.Target)"
            return $false
        }
    }
}

function Deploy-Local {
    <#
    .SYNOPSIS
    Starts application locally
    #>
    
    Write-Info "Starting application locally..."
    
    # Use the development script for local deployment
    $devScript = Join-Path (Split-Path $scriptDir) "development\start-local.ps1"
    
    if (Test-Path $devScript) {
        & $devScript -Environment $Global:BuildConfig.Environment
        return $LASTEXITCODE -eq 0
    } else {
        Write-Warning "⚠️ Local development script not found, starting with Maven..."
        
        Push-Location $Global:BuildConfig.ProjectRoot
        
        try {
            Write-Info "Starting Spring Boot application..."
            Write-Info "Press Ctrl+C to stop the application"
            
            & ./mvnw spring-boot:run -P$($Global:BuildConfig.Environment)
            
            return $LASTEXITCODE -eq 0
            
        } finally {
            Pop-Location
        }
    }
}

function Deploy-Docker {
    <#
    .SYNOPSIS
    Deploys application using Docker
    #>
    
    Write-Info "Deploying with Docker..."
    
    $imageName = "hazelcast-demo:$($Global:BuildConfig.ImageTag)"
    $containerName = "hazelcast-demo-$($Global:BuildConfig.Environment)"
    
    # Stop existing container
    & docker stop $containerName 2>$null
    & docker rm $containerName 2>$null
    
    # Run new container
    $runArgs = @(
        "run", "-d"
        "--name", $containerName
        "-p", "8080:8080"
        "-e", "SPRING_PROFILES_ACTIVE=$($Global:BuildConfig.Environment)"
    )
    
    if ($Global:BuildConfig.BuildInfo.Version) {
        $runArgs += "-e", "BUILD_VERSION=$($Global:BuildConfig.BuildInfo.Version)"
    }
    
    $runArgs += $imageName
    
    & docker @runArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Application deployed with Docker"
        Write-Host "   🌐 Application URL: http://localhost:8080" -ForegroundColor $Colors.Green
        Write-Host "   📚 Swagger UI: http://localhost:8080/swagger-ui.html" -ForegroundColor $Colors.Green
        Write-Host "   🐳 Container: $containerName" -ForegroundColor $Colors.Gray
        return $true
    } else {
        Write-Error "❌ Docker deployment failed"
        return $false
    }
}

function Deploy-OpenShift {
    <#
    .SYNOPSIS
    Deploys application to OpenShift
    #>
    
    Write-Info "Deploying to OpenShift..."
    
    # Use the OpenShift setup script
    $openshiftScript = Join-Path (Split-Path $scriptDir) "setup\setup-openshift-local.ps1"
    
    if (Test-Path $openshiftScript) {
        & $openshiftScript -Action deploy -Namespace $Global:BuildConfig.Namespace -ImageTag $Global:BuildConfig.ImageTag
        return $LASTEXITCODE -eq 0
    } else {
        Write-Error "❌ OpenShift setup script not found"
        return $false
    }
}

function Deploy-Kubernetes {
    <#
    .SYNOPSIS
    Deploys application to Kubernetes
    #>
    
    Write-Info "Deploying to Kubernetes..."
    
    $deploymentFile = Join-Path $Global:BuildConfig.ProjectRoot "deployment.yaml"
    
    if (Test-Path $deploymentFile) {
        # Apply deployment
        & kubectl apply -f $deploymentFile -n $Global:BuildConfig.Namespace
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ Application deployed to Kubernetes"
            
            # Wait for deployment
            Write-Info "Waiting for deployment to be ready..."
            & kubectl wait --for=condition=available --timeout=300s deployment/hazelcast-demo -n $Global:BuildConfig.Namespace
            
            return $LASTEXITCODE -eq 0
        } else {
            Write-Error "❌ Kubernetes deployment failed"
            return $false
        }
    } else {
        Write-Error "❌ Deployment file not found: $deploymentFile"
        return $false
    }
}

# ========================================================================
# REPORTING FUNCTIONS
# ========================================================================

function Show-BuildSummary {
    <#
    .SYNOPSIS
    Shows comprehensive build summary
    #>
    
    Write-Host ""
    Write-Host "📊 Build Summary" -ForegroundColor $Colors.White
    Write-Host "================" -ForegroundColor $Colors.White
    Write-Host ""
    
    $buildInfo = $Global:BuildConfig.BuildInfo
    $duration = $buildInfo.EndTime - $buildInfo.StartTime
    
    # Build information
    Write-Info "Build Information:"
    Write-Host "  • Environment: $($Global:BuildConfig.Environment)" -ForegroundColor $Colors.White
    Write-Host "  • Target: $($Global:BuildConfig.Target)" -ForegroundColor $Colors.White
    Write-Host "  • Version: $($buildInfo.Version)" -ForegroundColor $Colors.White
    Write-Host "  • Branch: $($buildInfo.Branch)" -ForegroundColor $Colors.White
    Write-Host "  • Commit: $($buildInfo.GitCommit.Substring(0, 8))" -ForegroundColor $Colors.White
    Write-Host "  • Duration: $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor $Colors.White
    Write-Host ""
    
    # Artifacts
    if ($buildInfo.Artifacts.Count -gt 0) {
        Write-Info "Build Artifacts:"
        foreach ($artifact in $buildInfo.Artifacts) {
            $file = Get-Item $artifact
            $size = [math]::Round($file.Length / 1MB, 2)
            Write-Host "  📦 $($file.Name) (${size} MB)" -ForegroundColor $Colors.Gray
        }
        Write-Host ""
    }
    
    # Result
    if ($buildInfo.Success) {
        Write-Host "🎉 BUILD SUCCESSFUL! 🎉" -ForegroundColor $Colors.Green
    } else {
        Write-Host "❌ BUILD FAILED" -ForegroundColor $Colors.Red
    }
    
    Write-Host ""
}

# ========================================================================
# MAIN ORCHESTRATION
# ========================================================================

function Invoke-BuildAndDeploy {
    <#
    .SYNOPSIS
    Main build and deploy orchestration
    #>
    
    Write-Host ""
    Write-Host "🏗️ Hazelcast Demo - Build & Deploy" -ForegroundColor $Colors.White
    Write-Host "===================================" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Info "Action: $($Global:BuildConfig.Action)"
    Write-Info "Environment: $($Global:BuildConfig.Environment)"
    Write-Info "Target: $($Global:BuildConfig.Target)"
    Write-Info "Image Tag: $($Global:BuildConfig.ImageTag)"
    Write-Host ""
    
    try {
        # Collect build information
        Get-BuildInformation
        Set-BuildEnvironment
        
        # Execute actions based on request
        $success = $true
        
        switch ($Global:BuildConfig.Action) {
            "build" {
                $success = Invoke-ProjectBuild
            }
            
            "test" {
                $success = Invoke-ProjectTests
            }
            
            "package" {
                $success = Invoke-ProjectBuild -and (Invoke-ProjectTests) -and (Invoke-ProjectPackage)
            }
            
            "deploy" {
                $success = Deploy-Application
            }
            
            "all" {
                $success = (Invoke-ProjectBuild) -and
                          (Invoke-ProjectTests) -and
                          (Invoke-ProjectPackage) -and
                          (Build-ContainerImage) -and
                          (Deploy-Application)
            }
        }
        
        # Update build info
        $Global:BuildConfig.BuildInfo.EndTime = Get-Date
        $Global:BuildConfig.BuildInfo.Success = $success
        
        # Show summary
        Show-BuildSummary
        
        return $success
        
    } catch {
        Write-Error "❌ Build and deploy failed: $($_.Exception.Message)"
        $Global:BuildConfig.BuildInfo.EndTime = Get-Date
        $Global:BuildConfig.BuildInfo.Success = $false
        Show-BuildSummary
        return $false
    }
}

# ========================================================================
# MAIN EXECUTION
# ========================================================================

# Set verbose logging if requested
if ($Verbose) {
    $Global:CurrentLogLevel = $LogLevels.DEBUG
}

# Execute main build and deploy
$result = Invoke-BuildAndDeploy

# Exit with appropriate code
exit $(if ($result) { 0 } else { 1 })
