# Hazelcast Demo - Local Development Startup Script (Windows)
# Usage: .\start-local-dev.ps1 [clean|test|debug]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("clean", "test", "debug", "help")]
    [string]$Command = ""
)

# Colors for output
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$BLUE = "Cyan"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $BLUE
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $GREEN
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $YELLOW
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $RED
}

function Test-JavaInstallation {
    try {
        $javaOutput = & java -version 2>&1
        if ($LASTEXITCODE -ne 0 -or $javaOutput -match "not recognized") {
            throw "Java not found"
        }
        
        $versionLine = $javaOutput | Where-Object { $_ -match "version" } | Select-Object -First 1
        if ($versionLine -match '"([^"]+)"') {
            $javaVersion = $matches[1]
            $majorVersion = ($javaVersion -split '\.')[0]
            
            if ([int]$majorVersion -lt 17) {
                Write-Error "Java version $javaVersion is not supported. Please use Java 17 or higher"
                exit 1
            }
            
            Write-Success "Java $javaVersion detected"
        } else {
            Write-Success "Java detected (version parsing failed but java command works)"
        }
    } catch {
        Write-Error "Java is not installed or not in PATH"
        Write-Info "Please install Java 17 or higher"
        exit 1
    }
}

function Invoke-CleanBuild {
    Write-Info "Cleaning previous build..."
    .\mvnw.cmd clean
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Build cleaned"
    } else {
        Write-Error "Clean build failed"
        exit 1
    }
}

function Invoke-Tests {
    Write-Info "Running tests..."
    .\mvnw.cmd test
    if ($LASTEXITCODE -eq 0) {
        Write-Success "All tests passed!"
    } else {
        Write-Error "Some tests failed"
        exit 1
    }
}

function Start-DevApplication {
    Write-Info "Starting Hazelcast Demo in development mode..."
    Write-Info "Profile: dev (H2 Database + Multicast Discovery)"
    Write-Info "Application will be available at: http://localhost:8080"
    Write-Info "H2 Console: http://localhost:8080/h2-console"
    Write-Info "Swagger UI: http://localhost:8080/swagger-ui.html"
    Write-Info "Health Check: http://localhost:8080/actuator/health"
    Write-Host ""
    Write-Warning "Press Ctrl+C to stop the application"
    Write-Host ""
    
    .\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=dev"
}

function Start-DebugApplication {
    Write-Info "Starting Hazelcast Demo in DEBUG mode..."
    Write-Info "Debug port: 5005"
    Write-Info "Connect your IDE debugger to localhost:5005"
    Write-Host ""
    
    .\mvnw.cmd spring-boot:run `
        "-Dspring-boot.run.profiles=dev" `
        "-Dspring-boot.run.jvmArguments=-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005"
}

function Show-Usage {
    Write-Host "Hazelcast Demo - Local Development Startup Script (Windows)" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\start-local-dev.ps1 [-Command] <command>" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  clean    Clean build before starting" -ForegroundColor White
    Write-Host "  test     Run tests before starting" -ForegroundColor White
    Write-Host "  debug    Start in debug mode (port 5005)" -ForegroundColor White
    Write-Host "  help     Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\start-local-dev.ps1           # Start normally" -ForegroundColor White
    Write-Host "  .\start-local-dev.ps1 clean     # Clean build and start" -ForegroundColor White
    Write-Host "  .\start-local-dev.ps1 test      # Run tests and start" -ForegroundColor White
    Write-Host "  .\start-local-dev.ps1 debug     # Start in debug mode" -ForegroundColor White
}

# Main execution
Write-Host "🚀 Hazelcast Demo - Local Development Startup" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host ""

Test-JavaInstallation

switch ($Command) {
    "clean" {
        Invoke-CleanBuild
        Start-DevApplication
    }
    "test" {
        Invoke-Tests
        Start-DevApplication
    }
    "debug" {
        Start-DebugApplication
    }
    "help" {
        Show-Usage
    }
    "" {
        Start-DevApplication
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}
