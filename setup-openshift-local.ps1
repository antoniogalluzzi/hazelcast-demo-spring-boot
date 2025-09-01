# OpenShift Local Setup Script for Hazelcast Demo (Windows)
# Usage: .\setup-openshift-local.ps1 [start|stop|deploy|cleanup]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("start", "stop", "deploy", "test", "cleanup", "info", "help")]
    [string]$Command = "help"
)

# Configuration
$PROJECT_NAME = "hazelcast-demo-dev"
$APP_NAME = "hazelcast-demo"
$DB_NAME = "postgresql"
$DB_USER = "hazelcast"
$DB_PASSWORD = "hazelcast123"

# Colors for output
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$BLUE = "Cyan"
$WHITE = "White"

function Write-ColorOutput {
    param(
        [string]$Color,
        [string]$Level,
        [string]$Message
    )
    Write-Host "[$Level] $Message" -ForegroundColor $Color
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput $BLUE "INFO" $Message
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput $GREEN "SUCCESS" $Message
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput $YELLOW "WARNING" $Message
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput $RED "ERROR" $Message
}

function Test-CRC {
    if (!(Get-Command crc -ErrorAction SilentlyContinue)) {
        Write-Error "CRC (OpenShift Local) is not installed or not in PATH"
        Write-Info "Download from: https://console.redhat.com/openshift/create/local"
        exit 1
    }
}

function Test-OC {
    if (!(Get-Command oc -ErrorAction SilentlyContinue)) {
        Write-Error "OpenShift CLI (oc) is not installed or not in PATH"
        Write-Info "Download from: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
        exit 1
    }
}

function Start-CRC {
    Write-Info "Starting OpenShift Local..."
    crc setup
    crc start --cpus 4 --memory 8192

    Write-Info "Configuring OpenShift CLI..."
    crc oc-env | Invoke-Expression

    Write-Success "OpenShift Local started successfully!"
    Write-Info "Console URL: $(crc console --url)"
    Write-Info "API URL: https://api.crc.testing:6443"
}

function Stop-CRC {
    Write-Info "Stopping OpenShift Local..."
    crc stop
    Write-Success "OpenShift Local stopped!"
}

function Connect-Cluster {
    Write-Info "Logging into OpenShift cluster..."
    $password = (crc console --credentials | Select-String "Password:" | ForEach-Object { $_.Line -split ":\s*" | Select-Object -Last 1 })
    oc login -u kubeadmin -p $password https://api.crc.testing:6443 --insecure-skip-tls-verify=$true
    Write-Success "Logged in successfully!"
}

function New-Project {
    Write-Info "Creating project: $PROJECT_NAME"
    try {
        oc new-project $PROJECT_NAME
    } catch {
        Write-Warning "Project already exists"
    }
    oc project $PROJECT_NAME
    Write-Success "Project ready!"
}

function Deploy-Database {
    Write-Info "Deploying PostgreSQL database..."

    # Check if already exists
    $existingPods = oc get pods -l app=$DB_NAME 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "PostgreSQL already deployed"
        return
    }

    # Deploy PostgreSQL
    oc new-app postgresql-ephemeral `
        --param DATABASE_SERVICE_NAME=$DB_NAME `
        --param POSTGRESQL_DATABASE=hazelcastdb `
        --param POSTGRESQL_USER=$DB_USER `
        --param POSTGRESQL_PASSWORD=$DB_PASSWORD `
        --param POSTGRESQL_VERSION=13

    Write-Info "Waiting for PostgreSQL to be ready..."
    oc wait --for=condition=ready pod -l app=$DB_NAME --timeout=300s

    Write-Success "PostgreSQL deployed successfully!"
}

function New-DBSecret {
    Write-Info "Creating database secret..."

    # Check if secret exists
    $existingSecret = oc get secret db-secret 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Database secret already exists"
        return
    }

    oc create secret generic db-secret `
        --from-literal=host=$DB_NAME.$PROJECT_NAME.svc.cluster.local `
        --from-literal=dbname=hazelcastdb `
        --from-literal=username=$DB_USER `
        --from-literal=password=$DB_PASSWORD

    Write-Success "Database secret created!"
}

function Deploy-Application {
    Write-Info "Building and deploying application..."

    # Create build if it doesn't exist
    $existingBC = oc get bc $APP_NAME 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Creating build configuration..."
        oc new-build --name=$APP_NAME --binary --image-stream=java:openjdk-21-ubi8:latest
    }

    # Start build
    Write-Info "Starting build..."
    oc start-build $APP_NAME --from-dir=. --follow

    # Deploy application
    Write-Info "Deploying application..."
    oc new-app $APP_NAME`:latest` `
        --name=$APP_NAME `
        --env=DB_HOST=$DB_NAME.$PROJECT_NAME.svc.cluster.local `
        --env=DB_NAME=hazelcastdb `
        --env=DB_USERNAME=$DB_USER `
        --env=DB_PASSWORD=$DB_PASSWORD

    # Wait for deployment
    Write-Info "Waiting for application to be ready..."
    oc wait --for=condition=available deployment/$APP_NAME --timeout=300s

    # Scale to 2 replicas for cache testing
    Write-Info "Scaling to 2 replicas..."
    oc scale deployment $APP_NAME --replicas=2

    Write-Success "Application deployed successfully!"
}

function Show-AppInfo {
    Write-Info "Application Information:"
    Write-Host ""
    Write-Info "Routes:"
    oc get routes
    Write-Host ""
    Write-Info "Pods:"
    oc get pods
    Write-Host ""
    Write-Info "Services:"
    oc get services
    Write-Host ""

    try {
        $route = (oc get routes -o jsonpath='{.items[0].spec.host}' 2>$null)
        if ($route) {
            Write-Success "Application URL: http://$route"
            Write-Info "Swagger UI: http://$route/swagger-ui.html"
            Write-Info "API Docs: http://$route/v3/api-docs"
            Write-Info "Health Check: http://$route/actuator/health"
            Write-Info "Actuator Metrics endpoint: http://$route/actuator/metrics"
        }
    } catch {
        Write-Warning "Could not retrieve route information"
    }
}

function Test-Application {
    Write-Info "Testing application..."

    try {
        $route = (oc get routes -o jsonpath='{.items[0].spec.host}' 2>$null)
        if (!$route) {
            Write-Error "No route found. Is the application deployed?"
            return
        }

        # Test health endpoint
        $healthResponse = Invoke-WebRequest -Uri "http://$route/actuator/health" -UseBasicParsing
        if ($healthResponse.Content -match '"status":"UP"') {
            Write-Success "Health check: PASSED"
        } else {
            Write-Error "Health check: FAILED"
        }

        # Test API
        $createResponse = Invoke-WebRequest -Uri "http://$route/user" -Method POST -Body '{"name": "Test User"}' -ContentType "application/json" -UseBasicParsing
        if ($createResponse.Content -match '"id"') {
            Write-Success "Create user: PASSED"
        } else {
            Write-Error "Create user: FAILED"
        }

        # Test cache
        $getResponse = Invoke-WebRequest -Uri "http://$route/user/1" -UseBasicParsing
        if ($getResponse.Content -match '"name"') {
            Write-Success "Get user (cache test): PASSED"
        } else {
            Write-Error "Get user (cache test): FAILED"
        }

        Write-Success "Application testing completed!"
    } catch {
        Write-Error "Testing failed: $($_.Exception.Message)"
    }
}

function Clear-Environment {
    Write-Warning "Cleaning up OpenShift Local environment..."
    oc delete project $PROJECT_NAME 2>$null
    Write-Success "Cleanup completed!"
}

function Show-Help {
    Write-Host "OpenShift Local Setup Script for Hazelcast Demo (Windows)" -ForegroundColor $WHITE
    Write-Host ""
    Write-Host "Usage: .\setup-openshift-local.ps1 [-Command] <command>" -ForegroundColor $WHITE
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor $WHITE
    Write-Host "  start     - Start OpenShift Local and setup environment" -ForegroundColor $WHITE
    Write-Host "  stop      - Stop OpenShift Local" -ForegroundColor $WHITE
    Write-Host "  deploy    - Deploy database and application" -ForegroundColor $WHITE
    Write-Host "  test      - Test the deployed application" -ForegroundColor $WHITE
    Write-Host "  cleanup   - Remove all resources" -ForegroundColor $WHITE
    Write-Host "  info      - Show application information" -ForegroundColor $WHITE
    Write-Host "  help      - Show this help message" -ForegroundColor $WHITE
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor $WHITE
    Write-Host "  .\setup-openshift-local.ps1 -Command start    # Start CRC and setup" -ForegroundColor $WHITE
    Write-Host "  .\setup-openshift-local.ps1 -Command deploy   # Deploy everything" -ForegroundColor $WHITE
    Write-Host "  .\setup-openshift-local.ps1 -Command test     # Test application" -ForegroundColor $WHITE
}

switch ($Command) {
    "start" {
        Test-CRC
        Start-CRC
        Connect-Cluster
        New-Project
    }
    "stop" {
        Test-CRC
        Stop-CRC
    }
    "deploy" {
        Test-OC
        Deploy-Database
        New-DBSecret
        Deploy-Application
        Show-AppInfo
    }
    "test" {
        Test-OC
        Test-Application
    }
    "cleanup" {
        Test-OC
        Clear-Environment
    }
    "info" {
        Test-OC
        Show-AppInfo
    }
    "help" {
        Show-Help
    }
    default {
        Show-Help
    }
}
