# ========================================================================
# OpenShift Local Setup Script for Hazelcast Demo
# ========================================================================
# Automated setup and deployment for Red Hat OpenShift Local (CRC)
# Author: Antonio Galluzzi (antonio.galluzzi91@gmail.com)
# Version: 2.0.0
# ========================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("install", "configure", "start", "deploy", "cleanup", "status", "all")]
    [string]$Action = "all",
    
    [Parameter(Mandatory=$false)]
    [string]$CrcVersion = "2.32.0",
    
    [Parameter(Mandatory=$false)]
    [int]$Memory = 16384,  # 16GB
    
    [Parameter(Mandatory=$false)]
    [int]$Cpus = 6,
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "hazelcast-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$ImageName = "hazelcast-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "latest",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanInstall,
    
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

$Global:OpenShiftConfig = @{
    CrcVersion = $CrcVersion
    Memory = $Memory
    Cpus = $Cpus
    Namespace = $Namespace
    ImageName = $ImageName
    ImageTag = $ImageTag
    PullSecret = $null
    AdminPassword = $null
    WebConsoleUrl = $null
    ApiUrl = $null
    RegistryUrl = $null
    Status = @{
        CrcInstalled = $false
        CrcRunning = $false
        ClusterReady = $false
        NamespaceExists = $false
        ApplicationDeployed = $false
    }
}

# ========================================================================
# CRC MANAGEMENT FUNCTIONS
# ========================================================================

function Test-OpenShiftLocalPrerequisites {
    <#
    .SYNOPSIS
    Checks prerequisites for OpenShift Local
    #>
    
    Write-Host ""
    Write-Host "🔍 Checking OpenShift Local Prerequisites" -ForegroundColor $Colors.Blue
    Write-Host "=========================================" -ForegroundColor $Colors.Blue
    
    $allGood = $true
    
    # Check Hyper-V (Windows)
    if ($IsWindows) {
        Write-Info "Checking Hyper-V configuration..."
        
        $hyperV = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        if ($hyperV -and $hyperV.State -eq "Enabled") {
            Write-Success "✅ Hyper-V is enabled"
        } else {
            Write-Warning "⚠️ Hyper-V is not enabled. Please enable it and restart."
            $allGood = $false
        }
    }
    
    # Check memory requirements
    Write-Info "Checking system memory..."
    $totalMemory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $requiredMemory = [math]::Round($Global:OpenShiftConfig.Memory / 1024, 2)
    
    if ($totalMemory -ge ($requiredMemory + 4)) {  # +4GB for host OS
        Write-Success "✅ Sufficient memory: ${totalMemory}GB (required: ${requiredMemory}GB + 4GB for host)"
    } else {
        Write-Warning "⚠️ Insufficient memory: ${totalMemory}GB (required: ${requiredMemory}GB + 4GB for host)"
        $allGood = $false
    }
    
    # Check CPU requirements
    Write-Info "Checking CPU configuration..."
    $cpuCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    
    if ($cpuCores -ge $Global:OpenShiftConfig.Cpus) {
        Write-Success "✅ Sufficient CPU cores: $cpuCores (required: $($Global:OpenShiftConfig.Cpus))"
    } else {
        Write-Warning "⚠️ Insufficient CPU cores: $cpuCores (required: $($Global:OpenShiftConfig.Cpus))"
        $allGood = $false
    }
    
    # Check disk space
    Write-Info "Checking disk space..."
    $diskSpace = [math]::Round((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB, 2)
    
    if ($diskSpace -ge 60) {  # 60GB minimum
        Write-Success "✅ Sufficient disk space: ${diskSpace}GB (minimum: 60GB)"
    } else {
        Write-Warning "⚠️ Insufficient disk space: ${diskSpace}GB (minimum: 60GB)"
        $allGood = $false
    }
    
    return $allGood
}

function Install-OpenShiftLocal {
    <#
    .SYNOPSIS
    Installs Red Hat OpenShift Local (CRC)
    #>
    
    Write-Host ""
    Write-Host "⬇️ Installing Red Hat OpenShift Local" -ForegroundColor $Colors.Blue
    Write-Host "====================================" -ForegroundColor $Colors.Blue
    
    # Check if already installed
    $crcPath = Get-Command "crc" -ErrorAction SilentlyContinue
    if ($crcPath -and -not $CleanInstall) {
        $installedVersion = & crc version 2>$null | Select-String "CRC version:" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        Write-Info "OpenShift Local is already installed (version: $installedVersion)"
        $Global:OpenShiftConfig.Status.CrcInstalled = $true
        return $true
    }
    
    if ($CleanInstall -and $crcPath) {
        Write-Info "Performing clean installation..."
        & crc delete --force 2>$null
        & crc cleanup 2>$null
    }
    
    # Download URL
    $downloadUrl = "https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/$($Global:OpenShiftConfig.CrcVersion)/crc-windows-amd64.zip"
    $downloadPath = Join-Path $env:TEMP "crc-windows-amd64.zip"
    $extractPath = Join-Path $env:TEMP "crc-extract"
    
    try {
        Write-Info "Downloading OpenShift Local $($Global:OpenShiftConfig.CrcVersion)..."
        
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadProgressChanged += {
            param($source, $eventArgs)
            Write-Progress -Activity "Downloading OpenShift Local" -Status "$($eventArgs.ProgressPercentage)% Complete" -PercentComplete $eventArgs.ProgressPercentage
        }
        $webClient.DownloadFileCompleted += {
            Write-Progress -Activity "Downloading OpenShift Local" -Completed
        }
        
        $webClient.DownloadFileAsync((New-Object System.Uri($downloadUrl)), $downloadPath)
        
        # Wait for download to complete
        while ($webClient.IsBusy) {
            Start-Sleep 1
        }
        
        Write-Success "✅ Download completed"
        
        # Extract
        Write-Info "Extracting OpenShift Local..."
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }
        
        Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
        
        # Find the CRC executable
        $crcExe = Get-ChildItem -Path $extractPath -Recurse -Name "crc.exe" | Select-Object -First 1
        if (-not $crcExe) {
            throw "Could not find crc.exe in extracted files"
        }
        
        $crcSourcePath = Join-Path $extractPath (Split-Path $crcExe)
        
        # Install to Program Files
        $installPath = "C:\Program Files\Red Hat OpenShift Local"
        
        Write-Info "Installing to $installPath..."
        if (-not (Test-Path $installPath)) {
            New-Item -Path $installPath -ItemType Directory -Force | Out-Null
        }
        
        Copy-Item -Path (Join-Path $crcSourcePath "*") -Destination $installPath -Recurse -Force
        
        # Add to PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($currentPath -notlike "*$installPath*") {
            Write-Info "Adding to system PATH..."
            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$installPath", "Machine")
            $env:PATH = "$env:PATH;$installPath"
        }
        
        Write-Success "✅ OpenShift Local installed successfully"
        $Global:OpenShiftConfig.Status.CrcInstalled = $true
        return $true
        
    } catch {
        Write-Error "❌ Failed to install OpenShift Local: $($_.Exception.Message)"
        return $false
        
    } finally {
        # Cleanup
        if (Test-Path $downloadPath) {
            Remove-Item $downloadPath -Force
        }
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }
    }
}

function Initialize-OpenShiftLocal {
    <#
    .SYNOPSIS
    Configures and initializes OpenShift Local
    #>
    
    Write-Host ""
    Write-Host "⚙️ Configuring OpenShift Local" -ForegroundColor $Colors.Blue
    Write-Host "==============================" -ForegroundColor $Colors.Blue
    
    # Request pull secret if not provided
    if (-not $Global:OpenShiftConfig.PullSecret) {
        Write-Host ""
        Write-Warning "⚠️ Red Hat Pull Secret Required"
        Write-Info "You need a Red Hat pull secret to download OpenShift images."
        Write-Info "Get your pull secret from: https://console.redhat.com/openshift/install/pull-secret"
        Write-Host ""
        
        $pullSecretPath = Read-Host "Enter path to pull secret file (or press Enter to skip)"
        
        if ($pullSecretPath -and (Test-Path $pullSecretPath)) {
            $Global:OpenShiftConfig.PullSecret = Get-Content $pullSecretPath -Raw
            Write-Success "✅ Pull secret loaded"
        } else {
            Write-Warning "⚠️ No pull secret provided. You'll need to configure it manually later."
        }
    }
    
    # Configure CRC
    Write-Info "Configuring CRC settings..."
    
    & crc config set memory $Global:OpenShiftConfig.Memory
    & crc config set cpus $Global:OpenShiftConfig.Cpus
    & crc config set disable-update-check true
    & crc config set consent-telemetry no
    
    Write-Success "✅ CRC configured"
    
    # Setup CRC
    Write-Info "Setting up CRC (this may take a few minutes)..."
    
    if ($Global:OpenShiftConfig.PullSecret) {
        $tempSecretFile = Join-Path $env:TEMP "pull-secret.txt"
        $Global:OpenShiftConfig.PullSecret | Out-File -FilePath $tempSecretFile -Encoding ASCII
        
        try {
            & crc setup --pull-secret-file $tempSecretFile
            $setupSuccess = $LASTEXITCODE -eq 0
        } finally {
            Remove-Item $tempSecretFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        & crc setup
        $setupSuccess = $LASTEXITCODE -eq 0
    }
    
    if ($setupSuccess) {
        Write-Success "✅ CRC setup completed"
        return $true
    } else {
        Write-Error "❌ CRC setup failed"
        return $false
    }
}

function Start-OpenShiftLocal {
    <#
    .SYNOPSIS
    Starts OpenShift Local cluster
    #>
    
    Write-Host ""
    Write-Host "🚀 Starting OpenShift Local Cluster" -ForegroundColor $Colors.Blue
    Write-Host "===================================" -ForegroundColor $Colors.Blue
    
    # Check if already running
    $status = & crc status 2>$null
    if ($status -and $status -match "Running") {
        Write-Info "OpenShift Local is already running"
        Get-OpenShiftLocalInfo
        return $true
    }
    
    Write-Info "Starting OpenShift Local cluster (this may take 10-15 minutes)..."
    Write-Info "☕ Perfect time for a coffee break!"
    
    $startTime = Get-Date
    
    # Start with retry logic
    $maxRetries = 3
    $retryCount = 0
    
    do {
        if ($retryCount -gt 0) {
            Write-Warning "⚠️ Attempt $($retryCount + 1) of $maxRetries"
            & crc delete --force 2>$null
            Start-Sleep 10
        }
        
        & crc start
        $startSuccess = $LASTEXITCODE -eq 0
        
        if (-not $startSuccess) {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Warning "Start failed, retrying..."
            }
        }
        
    } while (-not $startSuccess -and $retryCount -lt $maxRetries)
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    if ($startSuccess) {
        Write-Success "✅ OpenShift Local started successfully in $($duration.Minutes)m $($duration.Seconds)s"
        $Global:OpenShiftConfig.Status.CrcRunning = $true
        Get-OpenShiftLocalInfo
        return $true
    } else {
        Write-Error "❌ Failed to start OpenShift Local after $maxRetries attempts"
        return $false
    }
}

function Get-OpenShiftLocalInfo {
    <#
    .SYNOPSIS
    Retrieves OpenShift Local cluster information
    #>
    
    Write-Info "Retrieving cluster information..."
    
    # Get console info
    $consoleInfo = & crc console --credentials 2>$null
    if ($consoleInfo) {
        foreach ($line in $consoleInfo) {
            if ($line -match ".*console.*: (.*)") {
                $Global:OpenShiftConfig.WebConsoleUrl = $matches[1]
            } elseif ($line -match ".*admin.*: (.*)") {
                $Global:OpenShiftConfig.AdminPassword = $matches[1]
            }
        }
    }
    
    # Get API URL
    $apiInfo = & oc whoami --show-server 2>$null
    if ($apiInfo) {
        $Global:OpenShiftConfig.ApiUrl = $apiInfo
    }
    
    # Get registry URL
    $registryInfo = & oc registry info 2>$null
    if ($registryInfo) {
        $Global:OpenShiftConfig.RegistryUrl = $registryInfo
    }
    
    Write-Host ""
    Write-Success "🎯 OpenShift Local Cluster Information:"
    Write-Host "   Web Console: $($Global:OpenShiftConfig.WebConsoleUrl)" -ForegroundColor $Colors.Green
    Write-Host "   API Server: $($Global:OpenShiftConfig.ApiUrl)" -ForegroundColor $Colors.Green
    Write-Host "   Registry: $($Global:OpenShiftConfig.RegistryUrl)" -ForegroundColor $Colors.Green
    Write-Host "   Username: kubeadmin" -ForegroundColor $Colors.Green
    Write-Host "   Password: $($Global:OpenShiftConfig.AdminPassword)" -ForegroundColor $Colors.Green
    Write-Host ""
}

# ========================================================================
# DEPLOYMENT FUNCTIONS
# ========================================================================

function Build-ApplicationImage {
    <#
    .SYNOPSIS
    Builds application image for OpenShift
    #>
    
    if ($SkipBuild) {
        Write-Info "Skipping application build (--SkipBuild specified)"
        return $true
    }
    
    Write-Host ""
    Write-Host "🏗️ Building Application Image" -ForegroundColor $Colors.Blue
    Write-Host "=============================" -ForegroundColor $Colors.Blue
    
    $projectRoot = Get-ProjectRoot
    
    # Build with Maven
    Write-Info "Building application with Maven..."
    Push-Location $projectRoot
    
    try {
        & ./mvnw clean package -DskipTests -Popenshift-local
        
        if ($LASTEXITCODE -ne 0) {
            throw "Maven build failed"
        }
        
        Write-Success "✅ Maven build completed"
        
        # Build Docker image
        Write-Info "Building Docker image..."
        
        $imageName = "$($Global:OpenShiftConfig.ImageName):$($Global:OpenShiftConfig.ImageTag)"
        
        & docker build -t $imageName .
        
        if ($LASTEXITCODE -ne 0) {
            throw "Docker build failed"
        }
        
        Write-Success "✅ Docker image built: $imageName"
        
        # Tag for OpenShift registry
        $registryImage = "$($Global:OpenShiftConfig.RegistryUrl)/$($Global:OpenShiftConfig.Namespace)/$($Global:OpenShiftConfig.ImageName):$($Global:OpenShiftConfig.ImageTag)"
        
        & docker tag $imageName $registryImage
        
        if ($LASTEXITCODE -ne 0) {
            throw "Docker tag failed"
        }
        
        Write-Success "✅ Image tagged for OpenShift registry"
        return $true
        
    } catch {
        Write-Error "❌ Build failed: $($_.Exception.Message)"
        return $false
        
    } finally {
        Pop-Location
    }
}

function Deploy-ToOpenShift {
    <#
    .SYNOPSIS
    Deploys application to OpenShift Local
    #>
    
    Write-Host ""
    Write-Host "🚀 Deploying to OpenShift Local" -ForegroundColor $Colors.Blue
    Write-Host "===============================" -ForegroundColor $Colors.Blue
    
    # Login to OpenShift
    Write-Info "Logging in to OpenShift..."
    
    & oc login -u kubeadmin -p $Global:OpenShiftConfig.AdminPassword $Global:OpenShiftConfig.ApiUrl --insecure-skip-tls-verify=true
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Failed to login to OpenShift"
        return $false
    }
    
    Write-Success "✅ Logged in to OpenShift"
    
    # Create/switch to namespace
    Write-Info "Setting up namespace: $($Global:OpenShiftConfig.Namespace)"
    
    $namespaceExists = & oc get namespace $Global:OpenShiftConfig.Namespace 2>$null
    if (-not $namespaceExists) {
        & oc new-project $Global:OpenShiftConfig.Namespace
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Failed to create namespace"
            return $false
        }
        Write-Success "✅ Namespace created"
    } else {
        & oc project $Global:OpenShiftConfig.Namespace
        Write-Info "Using existing namespace"
    }
    
    $Global:OpenShiftConfig.Status.NamespaceExists = $true
    
    # Setup PostgreSQL database
    Write-Info "Deploying PostgreSQL database..."
    
    $dbExists = & oc get deployment postgresql 2>$null
    if (-not $dbExists) {
        
        # Create PostgreSQL deployment
        $postgresManifest = @"
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secret
type: Opaque
data:
  database-user: $(ConvertTo-Base64 "hazelcast")
  database-password: $(ConvertTo-Base64 "hazelcast123")
  database-name: $(ConvertTo-Base64 "hazelcastdb")
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  labels:
    app: postgresql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: registry.redhat.io/rhel8/postgresql-13:latest
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRESQL_USER
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: database-user
        - name: POSTGRESQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: database-password
        - name: POSTGRESQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: database-name
        volumeMounts:
        - name: postgresql-storage
          mountPath: /var/lib/pgsql/data
      volumes:
      - name: postgresql-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
spec:
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
"@
        
        $postgresManifest | & oc apply -f -
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Failed to deploy PostgreSQL"
            return $false
        }
        
        Write-Success "✅ PostgreSQL deployed"
        
        # Wait for PostgreSQL to be ready
        Write-Info "Waiting for PostgreSQL to be ready..."
        & oc wait --for=condition=available --timeout=300s deployment/postgresql
        
    } else {
        Write-Info "PostgreSQL already deployed"
    }
    
    # Push image to OpenShift registry
    if (-not $SkipBuild) {
        Write-Info "Pushing image to OpenShift registry..."
        
        # Login to registry
        & docker login -u kubeadmin -p $(& oc whoami -t) $Global:OpenShiftConfig.RegistryUrl
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Failed to login to OpenShift registry"
            return $false
        }
        
        # Push image
        $registryImage = "$($Global:OpenShiftConfig.RegistryUrl)/$($Global:OpenShiftConfig.Namespace)/$($Global:OpenShiftConfig.ImageName):$($Global:OpenShiftConfig.ImageTag)"
        
        & docker push $registryImage
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Failed to push image to registry"
            return $false
        }
        
        Write-Success "✅ Image pushed to registry"
    }
    
    # Deploy application
    Write-Info "Deploying Hazelcast Demo application..."
    
    $projectRoot = Get-ProjectRoot
    $deploymentFile = Join-Path $projectRoot "deployment.yaml"
    
    if (Test-Path $deploymentFile) {
        & oc apply -f $deploymentFile
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Failed to deploy application"
            return $false
        }
        
        Write-Success "✅ Application deployed"
        
        # Wait for deployment
        Write-Info "Waiting for application to be ready..."
        & oc wait --for=condition=available --timeout=300s deployment/hazelcast-demo
        
        # Create route
        $routeExists = & oc get route hazelcast-demo 2>$null
        if (-not $routeExists) {
            & oc expose service hazelcast-demo
            Write-Success "✅ Route created"
        }
        
        # Get application URL
        $appUrl = & oc get route hazelcast-demo -o jsonpath='{.spec.host}' 2>$null
        if ($appUrl) {
            Write-Host ""
            Write-Success "🎯 Application deployed successfully!"
            Write-Host "   Application URL: https://$appUrl" -ForegroundColor $Colors.Green
            Write-Host "   Swagger UI: https://$appUrl/swagger-ui.html" -ForegroundColor $Colors.Green
            Write-Host ""
        }
        
        $Global:OpenShiftConfig.Status.ApplicationDeployed = $true
        return $true
        
    } else {
        Write-Error "❌ Deployment file not found: $deploymentFile"
        return $false
    }
}

function ConvertTo-Base64 {
    param([string]$String)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($String)
    return [System.Convert]::ToBase64String($bytes)
}

# ========================================================================
# STATUS AND CLEANUP FUNCTIONS
# ========================================================================

function Show-OpenShiftStatus {
    <#
    .SYNOPSIS
    Shows OpenShift Local status
    #>
    
    Write-Host ""
    Write-Host "📊 OpenShift Local Status" -ForegroundColor $Colors.Blue
    Write-Host "=========================" -ForegroundColor $Colors.Blue
    
    # CRC Status
    $crcStatus = & crc status 2>$null
    
    Write-Host ""
    Write-Info "CRC Status:"
    if ($crcStatus) {
        $crcStatus | ForEach-Object {
            Write-Host "  $_" -ForegroundColor $Colors.White
        }
    } else {
        Write-Host "  Not installed or not responding" -ForegroundColor $Colors.Red
    }
    
    # Cluster info
    if ($Global:OpenShiftConfig.Status.CrcRunning) {
        Write-Host ""
        Write-Info "Cluster Information:"
        Write-Host "  Web Console: $($Global:OpenShiftConfig.WebConsoleUrl)" -ForegroundColor $Colors.White
        Write-Host "  API Server: $($Global:OpenShiftConfig.ApiUrl)" -ForegroundColor $Colors.White
        Write-Host "  Username: kubeadmin" -ForegroundColor $Colors.White
        Write-Host "  Password: $($Global:OpenShiftConfig.AdminPassword)" -ForegroundColor $Colors.White
        
        # Application status
        Write-Host ""
        Write-Info "Application Status:"
        
        $appPods = & oc get pods -n $Global:OpenShiftConfig.Namespace --no-headers 2>$null
        if ($appPods) {
            $appPods | ForEach-Object {
                Write-Host "  $_" -ForegroundColor $Colors.White
            }
        } else {
            Write-Host "  No applications deployed" -ForegroundColor $Colors.Gray
        }
        
        # Routes
        $routes = & oc get routes -n $Global:OpenShiftConfig.Namespace --no-headers 2>$null
        if ($routes) {
            Write-Host ""
            Write-Info "Routes:"
            $routes | ForEach-Object {
                Write-Host "  $_" -ForegroundColor $Colors.White
            }
        }
    }
    
    Write-Host ""
}

function Remove-OpenShiftDeployment {
    <#
    .SYNOPSIS
    Removes application deployment from OpenShift
    #>
    
    Write-Host ""
    Write-Host "🧹 Cleaning up OpenShift Deployment" -ForegroundColor $Colors.Blue
    Write-Host "===================================" -ForegroundColor $Colors.Blue
    
    # Delete namespace
    Write-Info "Deleting namespace: $($Global:OpenShiftConfig.Namespace)"
    
    & oc delete namespace $Global:OpenShiftConfig.Namespace --ignore-not-found=true
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Namespace deleted"
    } else {
        Write-Warning "⚠️ Failed to delete namespace"
    }
    
    Write-Host ""
}

# ========================================================================
# MAIN ORCHESTRATION
# ========================================================================

function Invoke-OpenShiftLocalSetup {
    <#
    .SYNOPSIS
    Main OpenShift Local setup orchestration
    #>
    
    Write-Host ""
    Write-Host "🔴 Red Hat OpenShift Local Setup" -ForegroundColor $Colors.White
    Write-Host "================================" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Info "Action: $Action"
    Write-Info "Memory: $($Global:OpenShiftConfig.Memory)MB"
    Write-Info "CPUs: $($Global:OpenShiftConfig.Cpus)"
    Write-Info "Namespace: $($Global:OpenShiftConfig.Namespace)"
    Write-Host ""
    
    try {
        switch ($Action) {
            "install" {
                if (-not (Test-OpenShiftLocalPrerequisites)) {
                    Write-Error "❌ Prerequisites check failed"
                    return $false
                }
                
                return Install-OpenShiftLocal
            }
            
            "configure" {
                return Initialize-OpenShiftLocal
            }
            
            "start" {
                return Start-OpenShiftLocal
            }
            
            "deploy" {
                if (-not (Build-ApplicationImage)) {
                    return $false
                }
                
                return Deploy-ToOpenShift
            }
            
            "status" {
                Show-OpenShiftStatus
                return $true
            }
            
            "cleanup" {
                Remove-OpenShiftDeployment
                return $true
            }
            
            "all" {
                # Full setup workflow
                if (-not (Test-OpenShiftLocalPrerequisites)) {
                    Write-Error "❌ Prerequisites check failed"
                    return $false
                }
                
                if (-not (Install-OpenShiftLocal)) {
                    return $false
                }
                
                if (-not (Initialize-OpenShiftLocal)) {
                    return $false
                }
                
                if (-not (Start-OpenShiftLocal)) {
                    return $false
                }
                
                if (-not (Build-ApplicationImage)) {
                    return $false
                }
                
                if (-not (Deploy-ToOpenShift)) {
                    return $false
                }
                
                Write-Host ""
                Write-Success "🎉 OpenShift Local setup completed successfully!"
                Write-Info "You can now access your application through the OpenShift routes."
                Write-Host ""
                
                return $true
            }
        }
        
    } catch {
        Write-Error "❌ OpenShift Local setup failed: $($_.Exception.Message)"
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

# Execute main setup
$result = Invoke-OpenShiftLocalSetup

# Exit with appropriate code
exit $(if ($result) { 0 } else { 1 })
