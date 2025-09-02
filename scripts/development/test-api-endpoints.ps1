# ========================================================================
# API Endpoints Testing Script for Hazelcast Demo
# ========================================================================
# Comprehensive API testing with validation and performance metrics
# Author: Antonio Galluzzi (antonio.galluzzi91@gmail.com)
# Version: 2.0.0
# ========================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = "http://localhost:8080",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "comprehensive", "performance", "stress")]
    [string]$TestLevel = "comprehensive",
    
    [Parameter(Mandatory=$false)]
    [int]$Timeout = 30,
    
    [Parameter(Mandatory=$false)]
    [int]$PerformanceIterations = 10,
    
    [Parameter(Mandatory=$false)]
    [int]$StressIterations = 100,
    
    [Parameter(Mandatory=$false)]
    [int]$ConcurrentRequests = 5,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportResults,
    
    [Parameter(Mandatory=$false)]
    [string]$ResultsFile = "api-test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# Set error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"  # Continue on API errors for testing

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
# GLOBAL TEST CONFIGURATION
# ========================================================================

$Global:TestConfig = @{
    BaseUrl = $BaseUrl.TrimEnd('/')
    Timeout = $Timeout
    TestLevel = $TestLevel
    PerformanceIterations = $PerformanceIterations
    StressIterations = $StressIterations
    ConcurrentRequests = $ConcurrentRequests
    Results = @{
        StartTime = Get-Date
        EndTime = $null
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
        Categories = @{}
        Performance = @{}
        Errors = @()
    }
}

# ========================================================================
# TEST UTILITY FUNCTIONS
# ========================================================================

function Invoke-ApiRequest {
    <#
    .SYNOPSIS
    Makes HTTP request with error handling and metrics
    #>
    param(
        [string]$Method = "GET",
        [string]$Endpoint,
        [object]$Body = $null,
        [hashtable]$Headers = @{},
        [int]$TimeoutSec = $Global:TestConfig.Timeout
    )
    
    $uri = "$($Global:TestConfig.BaseUrl)$Endpoint"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $requestParams = @{
            Uri = $uri
            Method = $Method
            UseBasicParsing = $true
            TimeoutSec = $TimeoutSec
            Headers = $Headers
        }
        
        if ($Body) {
            if ($Body -is [string]) {
                $requestParams.Body = $Body
            } else {
                $requestParams.Body = $Body | ConvertTo-Json -Depth 10
            }
            
            if (-not $Headers.ContainsKey("Content-Type")) {
                $requestParams.Headers["Content-Type"] = "application/json"
            }
        }
        
        $response = Invoke-WebRequest @requestParams
        $sw.Stop()
        
        $result = @{
            Success = $true
            StatusCode = $response.StatusCode
            Content = $response.Content
            Headers = $response.Headers
            ResponseTime = $sw.ElapsedMilliseconds
            Error = $null
        }
        
        # Try to parse JSON content
        try {
            $result.ParsedContent = $response.Content | ConvertFrom-Json
        } catch {
            $result.ParsedContent = $null
        }
        
        return $result
        
    } catch {
        $sw.Stop()
        
        return @{
            Success = $false
            StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
            Content = $null
            ParsedContent = $null
            Headers = @{}
            ResponseTime = $sw.ElapsedMilliseconds
            Error = $_.Exception.Message
        }
    }
}

function Add-TestResult {
    <#
    .SYNOPSIS
    Adds test result to global results
    #>
    param(
        [string]$Category,
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = "",
        [object]$Details = $null,
        [int]$ResponseTime = 0
    )
    
    if (-not $Global:TestConfig.Results.Categories.ContainsKey($Category)) {
        $Global:TestConfig.Results.Categories[$Category] = @{
            Tests = @()
            Passed = 0
            Failed = 0
            TotalTime = 0
        }
    }
    
    $testResult = @{
        Name = $TestName
        Passed = $Passed
        Message = $Message
        Details = $Details
        ResponseTime = $ResponseTime
        Timestamp = Get-Date
    }
    
    $Global:TestConfig.Results.Categories[$Category].Tests += $testResult
    $Global:TestConfig.Results.Categories[$Category].TotalTime += $ResponseTime
    
    if ($Passed) {
        $Global:TestConfig.Results.PassedTests++
        $Global:TestConfig.Results.Categories[$Category].Passed++
    } else {
        $Global:TestConfig.Results.FailedTests++
        $Global:TestConfig.Results.Categories[$Category].Failed++
    }
    
    $Global:TestConfig.Results.TotalTests++
    
    # Log result
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    $icon = if ($Passed) { "✅" } else { "❌" }
    $color = if ($Passed) { $Colors.Green } else { $Colors.Red }
    
    Write-Host "  $icon [$status] $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "       $Message" -ForegroundColor $Colors.Gray
    }
    if ($ResponseTime -gt 0) {
        Write-Host "       Response time: ${ResponseTime}ms" -ForegroundColor $Colors.Gray
    }
}

# ========================================================================
# BASIC API TESTS
# ========================================================================

function Test-HealthEndpoints {
    <#
    .SYNOPSIS
    Tests health and actuator endpoints
    #>
    
    Write-Host ""
    Write-Host "🔍 Testing Health & Actuator Endpoints" -ForegroundColor $Colors.Blue
    Write-Host "=======================================" -ForegroundColor $Colors.Blue
    
    # Test main health endpoint
    $result = Invoke-ApiRequest -Endpoint "/actuator/health"
    $healthOk = $result.Success -and $result.StatusCode -eq 200
    
    Add-TestResult -Category "Health" -TestName "Health Endpoint" -Passed $healthOk -Message $(
        if ($healthOk) { 
            "Status: $($result.ParsedContent.status)" 
        } else { 
            "Error: $($result.Error)" 
        }
    ) -ResponseTime $result.ResponseTime
    
    if ($healthOk -and $result.ParsedContent) {
        $health = $result.ParsedContent
        
        # Test individual components
        if ($health.components) {
            foreach ($component in $health.components.PSObject.Properties) {
                $componentName = $component.Name
                $componentStatus = $component.Value.status
                $componentOk = $componentStatus -eq "UP"
                
                Add-TestResult -Category "Health" -TestName "Component: $componentName" -Passed $componentOk -Message "Status: $componentStatus"
            }
        }
    }
    
    # Test readiness endpoint
    $result = Invoke-ApiRequest -Endpoint "/actuator/health/readiness"
    $readinessOk = $result.Success -and $result.StatusCode -eq 200
    
    Add-TestResult -Category "Health" -TestName "Readiness Probe" -Passed $readinessOk -ResponseTime $result.ResponseTime
    
    # Test liveness endpoint
    $result = Invoke-ApiRequest -Endpoint "/actuator/health/liveness"
    $livenessOk = $result.Success -and $result.StatusCode -eq 200
    
    Add-TestResult -Category "Health" -TestName "Liveness Probe" -Passed $livenessOk -ResponseTime $result.ResponseTime
    
    # Test metrics endpoint
    $result = Invoke-ApiRequest -Endpoint "/actuator/metrics"
    $metricsOk = $result.Success -and $result.StatusCode -eq 200
    
    Add-TestResult -Category "Health" -TestName "Metrics Endpoint" -Passed $metricsOk -ResponseTime $result.ResponseTime
    
    # Test info endpoint
    $result = Invoke-ApiRequest -Endpoint "/actuator/info"
    $infoOk = $result.Success -and $result.StatusCode -eq 200
    
    Add-TestResult -Category "Health" -TestName "Info Endpoint" -Passed $infoOk -ResponseTime $result.ResponseTime
}

function Test-UserApiEndpoints {
    <#
    .SYNOPSIS
    Tests user API CRUD operations
    #>
    
    Write-Host ""
    Write-Host "👤 Testing User API Endpoints" -ForegroundColor $Colors.Blue
    Write-Host "==============================" -ForegroundColor $Colors.Blue
    
    $testUser = @{
        name = "API Test User $(Get-Date -Format 'HHmmss')"
        email = "api.test.$(Get-Date -Format 'HHmmss')@example.com"
    }
    
    # Test CREATE user
    Write-Debug "Testing user creation..."
    $createResult = Invoke-ApiRequest -Method "POST" -Endpoint "/api/users" -Body $testUser
    $createOk = $createResult.Success -and $createResult.StatusCode -eq 201
    
    Add-TestResult -Category "User API" -TestName "Create User" -Passed $createOk -Message $(
        if ($createOk) { 
            "User created with ID: $($createResult.ParsedContent.id)" 
        } else { 
            "Error: $($createResult.Error)" 
        }
    ) -ResponseTime $createResult.ResponseTime
    
    if (-not $createOk) {
        Write-Warning "User creation failed, skipping dependent tests"
        return
    }
    
    $userId = $createResult.ParsedContent.id
    
    # Test GET user by ID
    Write-Debug "Testing user retrieval..."
    $getResult = Invoke-ApiRequest -Endpoint "/api/users/$userId"
    $getOk = $getResult.Success -and $getResult.StatusCode -eq 200
    
    Add-TestResult -Category "User API" -TestName "Get User by ID" -Passed $getOk -Message $(
        if ($getOk) { 
            "Retrieved user: $($getResult.ParsedContent.name)" 
        } else { 
            "Error: $($getResult.Error)" 
        }
    ) -ResponseTime $getResult.ResponseTime
    
    # Validate retrieved user data
    if ($getOk -and $getResult.ParsedContent) {
        $retrievedUser = $getResult.ParsedContent
        $dataValid = $retrievedUser.name -eq $testUser.name -and $retrievedUser.email -eq $testUser.email
        
        Add-TestResult -Category "User API" -TestName "User Data Validation" -Passed $dataValid -Message $(
            if ($dataValid) { 
                "All fields match" 
            } else { 
                "Data mismatch detected" 
            }
        )
    }
    
    # Test GET all users
    Write-Debug "Testing users list retrieval..."
    $listResult = Invoke-ApiRequest -Endpoint "/api/users"
    $listOk = $listResult.Success -and $listResult.StatusCode -eq 200
    
    Add-TestResult -Category "User API" -TestName "Get All Users" -Passed $listOk -ResponseTime $listResult.ResponseTime
    
    # Test UPDATE user
    Write-Debug "Testing user update..."
    $updatedUser = @{
        name = "$($testUser.name) (Updated)"
        email = $testUser.email
    }
    
    $updateResult = Invoke-ApiRequest -Method "PUT" -Endpoint "/api/users/$userId" -Body $updatedUser
    $updateOk = $updateResult.Success -and $updateResult.StatusCode -eq 200
    
    Add-TestResult -Category "User API" -TestName "Update User" -Passed $updateOk -ResponseTime $updateResult.ResponseTime
    
    # Verify update
    if ($updateOk) {
        $verifyResult = Invoke-ApiRequest -Endpoint "/api/users/$userId"
        $verifyOk = $verifyResult.Success -and $verifyResult.ParsedContent.name -eq $updatedUser.name
        
        Add-TestResult -Category "User API" -TestName "Update Verification" -Passed $verifyOk -Message $(
            if ($verifyOk) { 
                "Update verified" 
            } else { 
                "Update not reflected" 
            }
        )
    }
    
    # Test DELETE user
    Write-Debug "Testing user deletion..."
    $deleteResult = Invoke-ApiRequest -Method "DELETE" -Endpoint "/api/users/$userId"
    $deleteOk = $deleteResult.Success -and $deleteResult.StatusCode -eq 204
    
    Add-TestResult -Category "User API" -TestName "Delete User" -Passed $deleteOk -ResponseTime $deleteResult.ResponseTime
    
    # Verify deletion
    if ($deleteOk) {
        $verifyDeleteResult = Invoke-ApiRequest -Endpoint "/api/users/$userId"
        $verifyDeleteOk = $verifyDeleteResult.StatusCode -eq 404
        
        Add-TestResult -Category "User API" -TestName "Delete Verification" -Passed $verifyDeleteOk -Message $(
            if ($verifyDeleteOk) { 
                "User properly deleted (404)" 
            } else { 
                "User still exists after deletion" 
            }
        )
    }
}

function Test-CacheEndpoints {
    <#
    .SYNOPSIS
    Tests cache-related endpoints
    #>
    
    Write-Host ""
    Write-Host "⚡ Testing Cache Endpoints" -ForegroundColor $Colors.Blue
    Write-Host "=========================" -ForegroundColor $Colors.Blue
    
    # Test cache stats endpoint
    $statsResult = Invoke-ApiRequest -Endpoint "/actuator/metrics/cache.gets"
    $statsOk = $statsResult.Success -and $statsResult.StatusCode -eq 200
    
    Add-TestResult -Category "Cache" -TestName "Cache Metrics" -Passed $statsOk -ResponseTime $statsResult.ResponseTime
    
    # Test Hazelcast actuator endpoint
    $hazelcastResult = Invoke-ApiRequest -Endpoint "/actuator/hazelcast"
    $hazelcastOk = $hazelcastResult.Success -and $hazelcastResult.StatusCode -eq 200
    
    Add-TestResult -Category "Cache" -TestName "Hazelcast Info" -Passed $hazelcastOk -Message $(
        if ($hazelcastOk -and $hazelcastResult.ParsedContent.members) { 
            "Cluster members: $($hazelcastResult.ParsedContent.members.Count)" 
        } else { 
            "No cluster info available" 
        }
    ) -ResponseTime $hazelcastResult.ResponseTime
}

function Test-DocumentationEndpoints {
    <#
    .SYNOPSIS
    Tests documentation endpoints
    #>
    
    Write-Host ""
    Write-Host "📚 Testing Documentation Endpoints" -ForegroundColor $Colors.Blue
    Write-Host "===================================" -ForegroundColor $Colors.Blue
    
    # Test Swagger UI
    $swaggerResult = Invoke-ApiRequest -Endpoint "/swagger-ui.html"
    $swaggerOk = $swaggerResult.Success -and $swaggerResult.StatusCode -eq 200
    
    Add-TestResult -Category "Documentation" -TestName "Swagger UI" -Passed $swaggerOk -ResponseTime $swaggerResult.ResponseTime
    
    # Test OpenAPI JSON
    $openApiResult = Invoke-ApiRequest -Endpoint "/v3/api-docs"
    $openApiOk = $openApiResult.Success -and $openApiResult.StatusCode -eq 200
    
    Add-TestResult -Category "Documentation" -TestName "OpenAPI Specification" -Passed $openApiOk -ResponseTime $openApiResult.ResponseTime
    
    # Validate OpenAPI content
    if ($openApiOk -and $openApiResult.ParsedContent) {
        $apiDoc = $openApiResult.ParsedContent
        $hasInfo = $null -ne $apiDoc.info
        $hasPaths = $null -ne $apiDoc.paths -and $apiDoc.paths.PSObject.Properties.Count -gt 0
        
        Add-TestResult -Category "Documentation" -TestName "OpenAPI Content Validation" -Passed ($hasInfo -and $hasPaths) -Message $(
            if ($hasInfo -and $hasPaths) { 
                "API: $($apiDoc.info.title) v$($apiDoc.info.version)" 
            } else { 
                "Invalid OpenAPI structure" 
            }
        )
    }
}

function Test-ErrorHandling {
    <#
    .SYNOPSIS
    Tests error handling scenarios
    #>
    
    Write-Host ""
    Write-Host "⚠️ Testing Error Handling" -ForegroundColor $Colors.Blue
    Write-Host "=========================" -ForegroundColor $Colors.Blue
    
    # Test 404 - Non-existent user
    $notFoundResult = Invoke-ApiRequest -Endpoint "/api/users/99999"
    $notFoundOk = $notFoundResult.StatusCode -eq 404
    
    Add-TestResult -Category "Error Handling" -TestName "404 Not Found" -Passed $notFoundOk -Message $(
        if ($notFoundOk) { 
            "Correctly returns 404" 
        } else { 
            "Expected 404, got $($notFoundResult.StatusCode)" 
        }
    ) -ResponseTime $notFoundResult.ResponseTime
    
    # Test 400 - Invalid request body
    $invalidBodyResult = Invoke-ApiRequest -Method "POST" -Endpoint "/api/users" -Body @{ invalidField = "test" }
    $invalidBodyOk = $invalidBodyResult.StatusCode -in @(400, 422)
    
    Add-TestResult -Category "Error Handling" -TestName "400 Bad Request" -Passed $invalidBodyOk -Message $(
        if ($invalidBodyOk) { 
            "Correctly validates request body" 
        } else { 
            "Expected 400/422, got $($invalidBodyResult.StatusCode)" 
        }
    ) -ResponseTime $invalidBodyResult.ResponseTime
    
    # Test malformed JSON
    $malformedResult = Invoke-ApiRequest -Method "POST" -Endpoint "/api/users" -Body '{"name": invalid json'
    $malformedOk = $malformedResult.StatusCode -eq 400
    
    Add-TestResult -Category "Error Handling" -TestName "Malformed JSON" -Passed $malformedOk -ResponseTime $malformedResult.ResponseTime
}

# ========================================================================
# PERFORMANCE TESTS
# ========================================================================

function Test-PerformanceBasic {
    <#
    .SYNOPSIS
    Basic performance tests
    #>
    
    Write-Host ""
    Write-Host "⚡ Testing Basic Performance" -ForegroundColor $Colors.Blue
    Write-Host "===========================" -ForegroundColor $Colors.Blue
    
    # Create test user for performance testing
    $testUser = @{
        name = "Performance Test User"
        email = "performance.test@example.com"
    }
    
    $createResult = Invoke-ApiRequest -Method "POST" -Endpoint "/api/users" -Body $testUser
    if (-not $createResult.Success) {
        Write-Warning "Could not create test user for performance testing"
        return
    }
    
    $userId = $createResult.ParsedContent.id
    
    try {
        # Test single request performance
        $singleRequestTimes = @()
        for ($i = 1; $i -le $Global:TestConfig.PerformanceIterations; $i++) {
            $result = Invoke-ApiRequest -Endpoint "/api/users/$userId"
            if ($result.Success) {
                $singleRequestTimes += $result.ResponseTime
            }
        }
        
        if ($singleRequestTimes.Count -gt 0) {
            $avgTime = [math]::Round(($singleRequestTimes | Measure-Object -Average).Average, 2)
            $minTime = ($singleRequestTimes | Measure-Object -Minimum).Minimum
            $maxTime = ($singleRequestTimes | Measure-Object -Maximum).Maximum
            
            $performanceOk = $avgTime -lt 500  # Less than 500ms average
            
            Add-TestResult -Category "Performance" -TestName "Single Request Performance" -Passed $performanceOk -Message $(
                "Avg: ${avgTime}ms, Min: ${minTime}ms, Max: ${maxTime}ms"
            ) -ResponseTime $avgTime
            
            $Global:TestConfig.Results.Performance.SingleRequest = @{
                Average = $avgTime
                Minimum = $minTime
                Maximum = $maxTime
                Iterations = $singleRequestTimes.Count
            }
        }
        
        # Test cache performance (repeated requests should be faster)
        Write-Debug "Testing cache performance..."
        $cacheTest1 = Invoke-ApiRequest -Endpoint "/api/users/$userId"
        Start-Sleep 1  # Ensure caching
        $cacheTest2 = Invoke-ApiRequest -Endpoint "/api/users/$userId"
        
        if ($cacheTest1.Success -and $cacheTest2.Success) {
            $cacheImprovement = $cacheTest1.ResponseTime -gt $cacheTest2.ResponseTime
            
            Add-TestResult -Category "Performance" -TestName "Cache Performance" -Passed $cacheImprovement -Message $(
                "First: $($cacheTest1.ResponseTime)ms, Cached: $($cacheTest2.ResponseTime)ms"
            )
        }
        
    } finally {
        # Cleanup test user
        Invoke-ApiRequest -Method "DELETE" -Endpoint "/api/users/$userId" | Out-Null
    }
}

function Test-PerformanceStress {
    <#
    .SYNOPSIS
    Stress performance tests
    #>
    
    if ($Global:TestConfig.TestLevel -ne "stress") {
        return
    }
    
    Write-Host ""
    Write-Host "🔥 Testing Stress Performance" -ForegroundColor $Colors.Blue
    Write-Host "=============================" -ForegroundColor $Colors.Blue
    
    # Create multiple test users
    $testUserIds = @()
    for ($i = 1; $i -le 10; $i++) {
        $testUser = @{
            name = "Stress Test User $i"
            email = "stress.test.$i@example.com"
        }
        
        $createResult = Invoke-ApiRequest -Method "POST" -Endpoint "/api/users" -Body $testUser
        if ($createResult.Success) {
            $testUserIds += $createResult.ParsedContent.id
        }
    }
    
    if ($testUserIds.Count -eq 0) {
        Write-Warning "Could not create test users for stress testing"
        return
    }
    
    try {
        # Stress test with multiple concurrent requests
        Write-Info "Running stress test with $($Global:TestConfig.StressIterations) requests..."
        
        $stressStartTime = Get-Date
        $successCount = 0
        $errorCount = 0
        $responseTimes = @()
        
        # Run concurrent requests
        $jobs = @()
        for ($i = 1; $i -le $Global:TestConfig.ConcurrentRequests; $i++) {
            $job = Start-Job -ScriptBlock {
                param($BaseUrl, $UserIds, $Iterations)
                
                $results = @()
                for ($j = 1; $j -le $Iterations; $j++) {
                    $userId = $UserIds | Get-Random
                    $sw = [System.Diagnostics.Stopwatch]::StartNew()
                    
                    try {
                        $response = Invoke-WebRequest -Uri "$BaseUrl/api/users/$userId" -UseBasicParsing -TimeoutSec 10
                        $sw.Stop()
                        
                        $results += @{
                            Success = $true
                            ResponseTime = $sw.ElapsedMilliseconds
                            StatusCode = $response.StatusCode
                        }
                    } catch {
                        $sw.Stop()
                        
                        $results += @{
                            Success = $false
                            ResponseTime = $sw.ElapsedMilliseconds
                            Error = $_.Exception.Message
                        }
                    }
                }
                
                return $results
            } -ArgumentList $Global:TestConfig.BaseUrl, $testUserIds, [math]::Floor($Global:TestConfig.StressIterations / $Global:TestConfig.ConcurrentRequests)
            
            $jobs += $job
        }
        
        # Wait for all jobs to complete
        $jobs | Wait-Job | Out-Null
        
        # Collect results
        foreach ($job in $jobs) {
            $jobResults = Receive-Job $job
            foreach ($result in $jobResults) {
                if ($result.Success) {
                    $successCount++
                    $responseTimes += $result.ResponseTime
                } else {
                    $errorCount++
                }
            }
            Remove-Job $job
        }
        
        $stressEndTime = Get-Date
        $totalDuration = ($stressEndTime - $stressStartTime).TotalSeconds
        $totalRequests = $successCount + $errorCount
        $throughput = [math]::Round($totalRequests / $totalDuration, 2)
        $errorRate = [math]::Round(($errorCount / $totalRequests) * 100, 2)
        
        if ($responseTimes.Count -gt 0) {
            $avgResponseTime = [math]::Round(($responseTimes | Measure-Object -Average).Average, 2)
            $p95ResponseTime = [math]::Round(($responseTimes | Sort-Object)[[math]::Floor($responseTimes.Count * 0.95)], 2)
        } else {
            $avgResponseTime = 0
            $p95ResponseTime = 0
        }
        
        $stressOk = $errorRate -lt 5 -and $avgResponseTime -lt 1000  # Less than 5% errors and 1s average
        
        Add-TestResult -Category "Performance" -TestName "Stress Test" -Passed $stressOk -Message $(
            "Requests: $totalRequests, Throughput: $throughput req/s, Error Rate: $errorRate%, Avg Response: ${avgResponseTime}ms"
        )
        
        $Global:TestConfig.Results.Performance.StressTest = @{
            TotalRequests = $totalRequests
            SuccessfulRequests = $successCount
            FailedRequests = $errorCount
            Duration = $totalDuration
            Throughput = $throughput
            ErrorRate = $errorRate
            AverageResponseTime = $avgResponseTime
            P95ResponseTime = $p95ResponseTime
        }
        
    } finally {
        # Cleanup test users
        foreach ($userId in $testUserIds) {
            Invoke-ApiRequest -Method "DELETE" -Endpoint "/api/users/$userId" | Out-Null
        }
    }
}

# ========================================================================
# TEST ORCHESTRATION
# ========================================================================

function Invoke-ApiTesting {
    <#
    .SYNOPSIS
    Main API testing orchestration
    #>
    
    Write-Host ""
    Write-Host "🧪 Hazelcast Demo - API Endpoints Testing" -ForegroundColor $Colors.White
    Write-Host "==========================================" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Info "Base URL: $($Global:TestConfig.BaseUrl)"
    Write-Info "Test Level: $($Global:TestConfig.TestLevel)"
    Write-Info "Timeout: $($Global:TestConfig.Timeout)s"
    Write-Host ""
    
    # Verify application is running
    Write-Info "🔍 Verifying application availability..."
    $healthCheck = Invoke-ApiRequest -Endpoint "/actuator/health"
    
    if (-not $healthCheck.Success) {
        Write-Error "❌ Application is not responding at $($Global:TestConfig.BaseUrl)"
        Write-Info "Make sure the application is running and accessible"
        exit 1
    }
    
    Write-Success "✅ Application is responding"
    Write-Host ""
    
    try {
        # Run test suites based on test level
        switch ($Global:TestConfig.TestLevel) {
            "basic" {
                Test-HealthEndpoints
                Test-UserApiEndpoints
            }
            "comprehensive" {
                Test-HealthEndpoints
                Test-UserApiEndpoints
                Test-CacheEndpoints
                Test-DocumentationEndpoints
                Test-ErrorHandling
                Test-PerformanceBasic
            }
            "performance" {
                Test-HealthEndpoints
                Test-UserApiEndpoints
                Test-PerformanceBasic
            }
            "stress" {
                Test-HealthEndpoints
                Test-UserApiEndpoints
                Test-PerformanceBasic
                Test-PerformanceStress
            }
        }
        
        # Finalize results
        $Global:TestConfig.Results.EndTime = Get-Date
        
        # Show summary
        Show-TestSummary
        
        # Export results if requested
        if ($ExportResults) {
            Export-TestResults
        }
        
        # Return success/failure
        return $Global:TestConfig.Results.FailedTests -eq 0
        
    } catch {
        Write-Error "❌ API testing failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-TestSummary {
    <#
    .SYNOPSIS
    Shows comprehensive test summary
    #>
    
    Write-Host ""
    Write-Host "📊 API Testing Summary" -ForegroundColor $Colors.White
    Write-Host "======================" -ForegroundColor $Colors.White
    Write-Host ""
    
    $results = $Global:TestConfig.Results
    $duration = $results.EndTime - $results.StartTime
    
    # Overall statistics
    Write-Info "Overall Results:"
    Write-Host "  • Total Tests: $($results.TotalTests)" -ForegroundColor $Colors.White
    Write-Host "  • Passed: $($results.PassedTests)" -ForegroundColor $Colors.Green
    Write-Host "  • Failed: $($results.FailedTests)" -ForegroundColor $(if ($results.FailedTests -gt 0) { $Colors.Red } else { $Colors.Green })
    Write-Host "  • Duration: $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor $Colors.White
    Write-Host ""
    
    # Category breakdown
    Write-Info "Results by Category:"
    foreach ($categoryName in ($results.Categories.Keys | Sort-Object)) {
        $category = $results.Categories[$categoryName]
        $avgTime = if ($category.Tests.Count -gt 0) { 
            [math]::Round($category.TotalTime / $category.Tests.Count, 2) 
        } else { 0 }
        
        Write-Host "  📁 $categoryName" -ForegroundColor $Colors.Blue
        Write-Host "    ✅ Passed: $($category.Passed)" -ForegroundColor $Colors.Green
        Write-Host "    ❌ Failed: $($category.Failed)" -ForegroundColor $(if ($category.Failed -gt 0) { $Colors.Red } else { $Colors.Green })
        Write-Host "    ⏱️ Avg Response Time: ${avgTime}ms" -ForegroundColor $Colors.Gray
        Write-Host ""
    }
    
    # Performance summary
    if ($results.Performance -and $results.Performance.Count -gt 0) {
        Write-Info "Performance Summary:"
        
        if ($results.Performance.SingleRequest) {
            $perfData = $results.Performance.SingleRequest
            Write-Host "  ⚡ Single Request: Avg $($perfData.Average)ms (Min: $($perfData.Minimum)ms, Max: $($perfData.Maximum)ms)" -ForegroundColor $Colors.White
        }
        
        if ($results.Performance.StressTest) {
            $stress = $results.Performance.StressTest
            Write-Host "  🔥 Stress Test: $($stress.Throughput) req/s, $($stress.ErrorRate)% errors" -ForegroundColor $Colors.White
        }
        
        Write-Host ""
    }
    
    # Failed tests details
    if ($results.FailedTests -gt 0) {
        Write-Host "❌ Failed Tests Details:" -ForegroundColor $Colors.Red
        foreach ($categoryName in $results.Categories.Keys) {
            $failedTests = $results.Categories[$categoryName].Tests | Where-Object { -not $_.Passed }
            foreach ($test in $failedTests) {
                Write-Host "  • [$categoryName] $($test.Name): $($test.Message)" -ForegroundColor $Colors.Red
            }
        }
        Write-Host ""
    }
    
    # Overall result
    if ($results.FailedTests -eq 0) {
        Write-Host "🎉 ALL TESTS PASSED! 🎉" -ForegroundColor $Colors.Green
    } else {
        Write-Host "⚠️ $($results.FailedTests) TEST(S) FAILED" -ForegroundColor $Colors.Red
    }
    
    Write-Host ""
}

function Export-TestResults {
    <#
    .SYNOPSIS
    Exports test results to JSON file
    #>
    
    Write-Info "📄 Exporting test results to: $ResultsFile"
    
    $exportData = @{
        Summary = @{
            TestLevel = $Global:TestConfig.TestLevel
            BaseUrl = $Global:TestConfig.BaseUrl
            StartTime = $Global:TestConfig.Results.StartTime
            EndTime = $Global:TestConfig.Results.EndTime
            Duration = ($Global:TestConfig.Results.EndTime - $Global:TestConfig.Results.StartTime).TotalSeconds
            TotalTests = $Global:TestConfig.Results.TotalTests
            PassedTests = $Global:TestConfig.Results.PassedTests
            FailedTests = $Global:TestConfig.Results.FailedTests
        }
        Categories = $Global:TestConfig.Results.Categories
        Performance = $Global:TestConfig.Results.Performance
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ResultsFile -Encoding UTF8
    
    Write-Success "✅ Results exported to: $ResultsFile"
}

# ========================================================================
# MAIN EXECUTION
# ========================================================================

# Set verbose logging if requested
if ($Verbose) {
    $Global:CurrentLogLevel = $LogLevels.DEBUG
}

# Execute main testing
$testResult = Invoke-ApiTesting

# Exit with appropriate code
exit $(if ($testResult) { 0 } else { 1 })
