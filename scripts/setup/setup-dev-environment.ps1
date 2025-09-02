# ========================================================================
# Development Environment Setup Script for Hazelcast Demo
# ========================================================================
# Comprehensive setup script for local development environment
# Author: Antonio Galluzzi (antonio.galluzzi91@gmail.com)
# Version: 2.0.0
# ========================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("quick", "standard", "full")]
    [string]$SetupType = "standard",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipChecks,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$StartApplication,
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
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

$Global:SetupConfig = @{
    Environment = "dev"
    Profile = "dev"
    Database = "H2"
    Port = $Port
    JavaMinVersion = 17
    SetupSteps = @{
        "quick" = @("prerequisites", "build")
        "standard" = @("prerequisites", "build", "test", "configure")
        "full" = @("prerequisites", "build", "test", "configure", "validate", "documentation")
    }
}

# ========================================================================
# SETUP FUNCTIONS
# ========================================================================

function Test-Prerequisites {
    <#
    .SYNOPSIS
    Verifies all development prerequisites
    #>
    
    Write-Host ""
    Write-Host "📋 Step 1: Prerequisites Verification" -ForegroundColor $Colors.Blue
    Write-Host "=====================================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    # Run environment check
    $envCheckScript = Join-Path (Split-Path $scriptDir) "utilities\environment-check.ps1"
    
    if (Test-Path $envCheckScript) {
        Write-Info "Running comprehensive environment check..."
        $checkResult = & $envCheckScript -Environment "dev" -CheckLevel "detailed"
        
        if (-not $checkResult -or $LASTEXITCODE -ne 0) {
            if ($Force) {
                Write-Warning "Prerequisites check failed but Force mode enabled - continuing"
            } else {
                Write-Error "Prerequisites check failed. Use -Force to continue anyway"
                throw "Prerequisites not met"
            }
        } else {
            Write-Success "All prerequisites verified successfully"
        }
    } else {
        # Fallback to basic checks
        Write-Info "Running basic prerequisite checks..."
        
        if (-not (Test-JavaInstallation -MinVersion $Global:SetupConfig.JavaMinVersion)) {
            throw "Java $($Global:SetupConfig.JavaMinVersion)+ is required"
        }
        
        if (-not (Test-MavenInstallation)) {
            throw "Maven is required"
        }
        
        Write-Success "Basic prerequisites verified"
    }
}

function Invoke-ProjectBuild {
    <#
    .SYNOPSIS
    Builds the project with Maven
    #>
    
    Write-Host ""
    Write-Host "🔨 Step 2: Project Build" -ForegroundColor $Colors.Blue
    Write-Host "========================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    # Ensure we're in the project root
    if (-not (Test-Path "pom.xml")) {
        $projectRoot = Split-Path (Split-Path $scriptDir) -Parent
        if (Test-Path (Join-Path $projectRoot "pom.xml")) {
            Set-Location $projectRoot
            Write-Info "Changed to project root: $projectRoot"
        } else {
            throw "Cannot find pom.xml - not in project root directory"
        }
    }
    
    Write-Info "Building project with Maven..."
    
    # Clean build
    $buildResult = Invoke-MavenBuild -Goals "clean compile" -SkipTests
    
    if (-not $buildResult) {
        throw "Project build failed"
    }
    
    Write-Success "Project build completed successfully"
}

function Invoke-ProjectTests {
    <#
    .SYNOPSIS
    Runs project tests
    #>
    
    Write-Host ""
    Write-Host "🧪 Step 3: Running Tests" -ForegroundColor $Colors.Blue
    Write-Host "========================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    Write-Info "Running unit tests..."
    
    $testResult = Invoke-MavenBuild -Goals "test" -Profile $Global:SetupConfig.Profile
    
    if (-not $testResult) {
        if ($Force) {
            Write-Warning "Tests failed but Force mode enabled - continuing"
        } else {
            throw "Tests failed. Use -Force to continue anyway"
        }
    } else {
        Write-Success "All tests passed successfully"
    }
}

function Set-DevelopmentConfiguration {
    <#
    .SYNOPSIS
    Configures development environment
    #>
    
    Write-Host ""
    Write-Host "⚙️ Step 4: Development Configuration" -ForegroundColor $Colors.Blue
    Write-Host "====================================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    # Verify configuration files
    $configFiles = @(
        "src\main\resources\application.yml",
        "src\main\resources\application-dev.yml"
    )
    
    foreach ($configFile in $configFiles) {
        if (Test-Path $configFile) {
            Write-Success "Configuration file found: $configFile"
        } else {
            Write-Warning "Configuration file missing: $configFile"
        }
    }
    
    # Check H2 configuration
    Write-Info "Verifying H2 database configuration..."
    
    $devConfigPath = "src\main\resources\application-dev.yml"
    if (Test-Path $devConfigPath) {
        $devConfig = Get-Content $devConfigPath -Raw
        if ($devConfig -match "h2:mem:testdb") {
            Write-Success "H2 in-memory database configured"
        } else {
            Write-Warning "H2 configuration may not be correct"
        }
    }
    
    # Create logs directory
    $logsDir = "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        Write-Success "Created logs directory: $logsDir"
    } else {
        Write-Info "Logs directory already exists: $logsDir"
    }
    
    Write-Success "Development configuration verified"
}

function Test-DevelopmentSetup {
    <#
    .SYNOPSIS
    Validates the development setup
    #>
    
    Write-Host ""
    Write-Host "✅ Step 5: Validation" -ForegroundColor $Colors.Blue
    Write-Host "=====================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    Write-Info "Validating development environment setup..."
    
    # Test Maven wrapper
    if (Test-Path ".\mvnw.cmd") {
        Write-Success "Maven wrapper available"
    } else {
        Write-Warning "Maven wrapper not found"
    }
    
    # Test if we can compile
    Write-Info "Testing compilation..."
    $compileResult = Invoke-MavenBuild -Goals "compile" -SkipTests
    
    if ($compileResult) {
        Write-Success "Project compiles successfully"
    } else {
        Write-Warning "Compilation issues detected"
    }
    
    # Check for application class
    $mainClass = "src\main\java\com\example\hazelcastdemo\HazelcastDemoApplication.java"
    if (Test-Path $mainClass) {
        Write-Success "Main application class found"
    } else {
        Write-Warning "Main application class not found at expected location"
    }
    
    Write-Success "Development setup validation completed"
}

function Show-DevelopmentDocumentation {
    <#
    .SYNOPSIS
    Shows development documentation and next steps
    #>
    
    Write-Host ""
    Write-Host "📚 Step 6: Development Documentation" -ForegroundColor $Colors.Blue
    Write-Host "====================================" -ForegroundColor $Colors.Blue
    Write-Host ""
    
    Write-Host "🎯 Development Environment Ready!" -ForegroundColor $Colors.Green
    Write-Host ""
    
    Write-Info "Environment Configuration:"
    Write-Host "  • Profile: $($Global:SetupConfig.Profile)" -ForegroundColor $Colors.White
    Write-Host "  • Database: $($Global:SetupConfig.Database) (in-memory)" -ForegroundColor $Colors.White
    Write-Host "  • Port: $($Global:SetupConfig.Port)" -ForegroundColor $Colors.White
    Write-Host "  • Java Version: $($Global:SetupConfig.JavaMinVersion)+" -ForegroundColor $Colors.White
    Write-Host ""
    
    Write-Info "Quick Start Commands:"
    Write-Host "  # Start application" -ForegroundColor $Colors.Gray
    Write-Host "  .\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=dev" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "  # Start with custom port" -ForegroundColor $Colors.Gray
    Write-Host "  .\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=dev -Dspring-boot.run.jvmArguments='-Dserver.port=8081'" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "  # Run tests" -ForegroundColor $Colors.Gray
    Write-Host "  .\mvnw.cmd test" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "  # Clean and rebuild" -ForegroundColor $Colors.Gray
    Write-Host "  .\mvnw.cmd clean package" -ForegroundColor $Colors.White
    Write-Host ""
    
    Write-Info "Development Scripts:"
    Write-Host "  # Start development with cluster" -ForegroundColor $Colors.Gray
    Write-Host "  .\scripts\development\start-local-dev.ps1 cluster" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "  # Performance testing" -ForegroundColor $Colors.Gray
    Write-Host "  .\scripts\testing\run-performance-tests.ps1" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "  # API testing" -ForegroundColor $Colors.Gray
    Write-Host "  .\scripts\development\test-api-endpoints.ps1" -ForegroundColor $Colors.White
    Write-Host ""
    
    Write-Info "Application Endpoints (when running):"
    Write-Host "  • Application: http://localhost:$($Global:SetupConfig.Port)" -ForegroundColor $Colors.White
    Write-Host "  • Health Check: http://localhost:$($Global:SetupConfig.Port)/actuator/health" -ForegroundColor $Colors.White
    Write-Host "  • H2 Console: http://localhost:$($Global:SetupConfig.Port)/h2-console" -ForegroundColor $Colors.White
    Write-Host "    - JDBC URL: jdbc:h2:mem:testdb" -ForegroundColor $Colors.Gray
    Write-Host "    - Username: sa" -ForegroundColor $Colors.Gray
    Write-Host "    - Password: (leave empty)" -ForegroundColor $Colors.Gray
    Write-Host "  • Swagger UI: http://localhost:$($Global:SetupConfig.Port)/swagger-ui.html" -ForegroundColor $Colors.White
    Write-Host "  • Metrics: http://localhost:$($Global:SetupConfig.Port)/actuator/metrics" -ForegroundColor $Colors.White
    Write-Host ""
    
    Write-Info "IDE Configuration:"
    Write-Host "  • Import as Maven project" -ForegroundColor $Colors.White
    Write-Host "  • Set Java version to 17+" -ForegroundColor $Colors.White
    Write-Host "  • Enable annotation processing" -ForegroundColor $Colors.White
    Write-Host "  • Use UTF-8 encoding" -ForegroundColor $Colors.White
    Write-Host ""
    
    Write-Info "Next Steps:"
    Write-Host "  1. Start the application with the quick start command above" -ForegroundColor $Colors.White
    Write-Host "  2. Open http://localhost:$($Global:SetupConfig.Port)/swagger-ui.html to explore APIs" -ForegroundColor $Colors.White
    Write-Host "  3. Use H2 console to inspect database" -ForegroundColor $Colors.White
    Write-Host "  4. Run cluster setup for distributed cache testing" -ForegroundColor $Colors.White
    Write-Host ""
}

function Start-Application {
    <#
    .SYNOPSIS
    Starts the application if requested
    #>
    
    if ($StartApplication) {
        Write-Host ""
        Write-Host "🚀 Starting Application" -ForegroundColor $Colors.Blue
        Write-Host "======================" -ForegroundColor $Colors.Blue
        Write-Host ""
        
        # Check if already running
        $appStatus = Test-ApplicationRunning -Port $Global:SetupConfig.Port
        if ($appStatus.Running) {
            Write-Warning "Application already running on port $($Global:SetupConfig.Port)"
            return
        }
        
        Write-Info "Starting Hazelcast Demo application..."
        Write-Info "Profile: $($Global:SetupConfig.Profile)"
        Write-Info "Port: $($Global:SetupConfig.Port)"
        Write-Info "Database: $($Global:SetupConfig.Database)"
        Write-Host ""
        Write-Warning "Application will start in foreground. Press Ctrl+C to stop."
        Write-Host ""
        
        # Start application
        $mvnCmd = if (Test-Path ".\mvnw.cmd") { ".\mvnw.cmd" } else { "mvn" }
        & $mvnCmd spring-boot:run "-Dspring-boot.run.profiles=$($Global:SetupConfig.Profile)" "-Dspring-boot.run.jvmArguments=-Dserver.port=$($Global:SetupConfig.Port)"
    }
}

# ========================================================================
# MAIN EXECUTION
# ========================================================================

function Invoke-DevelopmentSetup {
    <#
    .SYNOPSIS
    Main setup orchestration function
    #>
    
    Write-Host ""
    Write-Host "🚀 Hazelcast Demo - Development Environment Setup" -ForegroundColor $Colors.White
    Write-Host "=================================================" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Info "Setup Type: $SetupType"
    Write-Info "Target Environment: $($Global:SetupConfig.Environment)"
    Write-Info "Target Port: $($Global:SetupConfig.Port)"
    Write-Host ""
    
    # Get steps for setup type
    $stepsToRun = $Global:SetupConfig.SetupSteps[$SetupType]
    Write-Info "Steps to execute: $($stepsToRun -join ', ')"
    Write-Host ""
    
    $startTime = Get-Date
    
    try {
        # Execute setup steps
        foreach ($step in $stepsToRun) {
            switch ($step) {
                "prerequisites" {
                    if (-not $SkipChecks) {
                        Test-Prerequisites
                    } else {
                        Write-Warning "Skipping prerequisite checks (SkipChecks enabled)"
                    }
                }
                "build" {
                    if (-not $SkipBuild) {
                        Invoke-ProjectBuild
                    } else {
                        Write-Warning "Skipping build (SkipBuild enabled)"
                    }
                }
                "test" {
                    Invoke-ProjectTests
                }
                "configure" {
                    Set-DevelopmentConfiguration
                }
                "validate" {
                    Test-DevelopmentSetup
                }
                "documentation" {
                    Show-DevelopmentDocumentation
                }
            }
        }
        
        # Start application if requested
        Start-Application
        
        # Show completion summary
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host ""
        Write-Host "🎉 DEVELOPMENT SETUP COMPLETED! 🎉" -ForegroundColor $Colors.Green
        Write-Host "==================================" -ForegroundColor $Colors.Green
        Write-Host ""
        Write-Success "Setup completed in $($duration.Minutes)m $($duration.Seconds)s"
        Write-Success "Environment: Development ($($Global:SetupConfig.Profile) profile)"
        Write-Success "Database: $($Global:SetupConfig.Database) in-memory"
        Write-Success "Port: $($Global:SetupConfig.Port)"
        Write-Host ""
        
        if (-not $StartApplication) {
            Write-Info "To start the application, run:"
            Write-Host "  .\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=dev" -ForegroundColor $Colors.Yellow
        }
        
    } catch {
        Write-Host ""
        Write-Error "Development setup failed: $($_.Exception.Message)"
        Write-Host ""
        Write-Info "Troubleshooting:"
        Write-Host "  • Check prerequisites with: .\scripts\utilities\environment-check.ps1" -ForegroundColor $Colors.White
        Write-Host "  • Review error logs above" -ForegroundColor $Colors.White
        Write-Host "  • Use -Force to skip some validations" -ForegroundColor $Colors.White
        Write-Host "  • Use -Verbose for detailed output" -ForegroundColor $Colors.White
        
        exit 1
    }
}

# ========================================================================
# SCRIPT ENTRY POINT
# ========================================================================

# Set verbose logging if requested
if ($Verbose) {
    $Global:CurrentLogLevel = $LogLevels.DEBUG
}

# Execute main setup
Invoke-DevelopmentSetup
