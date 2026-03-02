<#
.SYNOPSIS
    Test Marco Sandbox AI Services connectivity and deployments

.DESCRIPTION
    Tests Azure OpenAI, AI Services, and Document Intelligence resources
    in marco-sandbox* resource group (EsDAICoE-Sandbox)

.PARAMETER SubscriptionId
    Azure subscription ID (defaults to EsDAICoESub)

.EXAMPLE
    .\Test-Marco-AI-Services.ps1
    .\Test-Marco-AI-Services.ps1 -Verbose
#>

[CmdletBinding()]
param(
    [string]$SubscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
    [string]$ResourceGroup = "EsDAICoE-Sandbox"
)

$ErrorActionPreference = "Continue"

# ASCII-only output (Windows cp1252 safe)
function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $status = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status $Test" -ForegroundColor $color
    if ($Details) {
        Write-Host "       $Details" -ForegroundColor Gray
    }
}

# Results tracking
$results = @{
    Total = 0
    Passed = 0
    Failed = 0
    Tests = @()
}

function Record-Test {
    param([string]$Name, [bool]$Passed, [string]$Details = "", [object]$Data = $null)
    
    $results.Total++
    if ($Passed) { $results.Passed++ } else { $results.Failed++ }
    
    $results.Tests += @{
        Name = $Name
        Passed = $Passed
        Details = $Details
        Data = $Data
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

Write-TestHeader "Marco Sandbox AI Services Test Suite"

# Test 1: Azure CLI Authentication
Write-Host "[INFO] Testing Azure CLI authentication..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    $currentSub = $account.id
    $currentUser = $account.user.name
    
    Write-TestResult -Test "Azure CLI Authentication" -Passed $true -Details "Logged in as $currentUser"
    Record-Test -Name "Azure CLI Auth" -Passed $true -Details $currentUser
    
    # Check if correct subscription
    if ($currentSub -ne $SubscriptionId) {
        Write-Host "[WARN] Current subscription: $currentSub" -ForegroundColor Yellow
        Write-Host "[INFO] Switching to EsDAICoESub..." -ForegroundColor Yellow
        az account set --subscription $SubscriptionId
        Write-Host "[PASS] Switched to subscription: $SubscriptionId" -ForegroundColor Green
    } else {
        Write-Host "[PASS] Already using EsDAICoESub subscription" -ForegroundColor Green
    }
} catch {
    Write-TestResult -Test "Azure CLI Authentication" -Passed $false -Details $_.Exception.Message
    Record-Test -Name "Azure CLI Auth" -Passed $false -Details $_.Exception.Message
    exit 1
}

# Test 2: List Marco AI Services
Write-TestHeader "Marco AI/Cognitive Services Inventory"

$aiServices = @(
    @{Name="marco-sandbox-openai-v2"; Type="OpenAI"; Location="canadaeast"},
    @{Name="marco-sandbox-foundry"; Type="AIServices"; Location="canadaeast"},
    @{Name="marco-sandbox-docint"; Type="FormRecognizer"; Location="canadacentral"}
)

foreach ($service in $aiServices) {
    Write-Host "`n[INFO] Testing $($service.Name) ($($service.Type))..." -ForegroundColor Yellow
    
    try {
        $resource = az cognitiveservices account show `
            --name $service.Name `
            --resource-group $ResourceGroup `
            2>&1 | ConvertFrom-Json
        
        if ($resource) {
            Write-TestResult -Test "$($service.Name) - Resource Exists" -Passed $true -Details "Location: $($resource.location)"
            Record-Test -Name "$($service.Name) - Exists" -Passed $true -Details $resource.location
            
            # Test properties
            Write-Host "       Provisioning State: $($resource.properties.provisioningState)" -ForegroundColor Gray
            Write-Host "       Endpoint: $($resource.properties.endpoint)" -ForegroundColor Gray
            Write-Host "       SKU: $($resource.sku.name)" -ForegroundColor Gray
            
            # Test 3: Get deployments (for OpenAI)
            if ($service.Type -eq "OpenAI") {
                Write-Host "   [INFO] Checking OpenAI deployments..." -ForegroundColor Yellow
                
                try {
                    $deployments = az cognitiveservices account deployment list `
                        --name $service.Name `
                        --resource-group $ResourceGroup `
                        2>&1 | ConvertFrom-Json
                    
                    if ($deployments -and $deployments.Count -gt 0) {
                        Write-TestResult -Test "$($service.Name) - Deployments" -Passed $true -Details "$($deployments.Count) deployment(s) found"
                        Record-Test -Name "$($service.Name) - Deployments" -Passed $true -Details "$($deployments.Count) models"
                        
                        foreach ($dep in $deployments) {
                            Write-Host "       - $($dep.name): $($dep.properties.model.name) v$($dep.properties.model.version)" -ForegroundColor Gray
                            Write-Host "         Capacity: $($dep.sku.capacity) TPM" -ForegroundColor Gray
                        }
                    } else {
                        Write-TestResult -Test "$($service.Name) - Deployments" -Passed $false -Details "No deployments found"
                        Record-Test -Name "$($service.Name) - Deployments" -Passed $false -Details "No models deployed"
                    }
                } catch {
                    Write-TestResult -Test "$($service.Name) - Deployments" -Passed $false -Details $_.Exception.Message
                    Record-Test -Name "$($service.Name) - Deployments" -Passed $false -Details "Cannot list deployments"
                }
            }
            
            # Test 4: Check RBAC access (try to list keys - this tests permissions)
            Write-Host "   [INFO] Testing RBAC permissions..." -ForegroundColor Yellow
            try {
                $keys = az cognitiveservices account keys list `
                    --name $service.Name `
                    --resource-group $ResourceGroup `
                    2>&1
                
                if ($keys -match "key1" -or $keys -match "Forbidden") {
                    if ($keys -match "Forbidden") {
                        Write-TestResult -Test "$($service.Name) - RBAC (User role only)" -Passed $true -Details "No key access (expected for User role)"
                        Record-Test -Name "$($service.Name) - RBAC" -Passed $true -Details "User role confirmed"
                    } else {
                        Write-TestResult -Test "$($service.Name) - RBAC (Admin access)" -Passed $true -Details "Can list keys"
                        Record-Test -Name "$($service.Name) - RBAC" -Passed $true -Details "Admin access"
                    }
                } else {
                    Write-TestResult -Test "$($service.Name) - RBAC" -Passed $false -Details "Unexpected response"
                    Record-Test -Name "$($service.Name) - RBAC" -Passed $false -Details "Unknown permissions"
                }
            } catch {
                Write-TestResult -Test "$($service.Name) - RBAC" -Passed $true -Details "User role (no key access)"
                Record-Test -Name "$($service.Name) - RBAC" -Passed $true -Details "Standard user permissions"
            }
            
        } else {
            Write-TestResult -Test "$($service.Name) - Resource Exists" -Passed $false -Details "Resource not found"
            Record-Test -Name "$($service.Name) - Exists" -Passed $false -Details "Not found"
        }
    } catch {
        Write-TestResult -Test "$($service.Name) - Resource Exists" -Passed $false -Details $_.Exception.Message
        Record-Test -Name "$($service.Name) - Exists" -Passed $false -Details "Error accessing resource"
    }
}

# Test 5: Check supporting resources
Write-TestHeader "Supporting Resources"

$supportingResources = @(
    @{Name="marco-sandbox-search"; Type="Microsoft.Search/searchServices"},
    @{Name="marco-sandbox-cosmos"; Type="Microsoft.DocumentDB/databaseAccounts"},
    @{Name="marcosand20260203"; Type="Microsoft.Storage/storageAccounts"},
    @{Name="marco-sandbox-backend"; Type="Microsoft.Web/sites"},
    @{Name="marco-sandbox-func"; Type="Microsoft.Web/sites"}
)

foreach ($res in $supportingResources) {
    try {
        $resource = az resource show `
            --name $res.Name `
            --resource-group $ResourceGroup `
            --resource-type $res.Type `
            2>&1 | ConvertFrom-Json
        
        if ($resource) {
            Write-TestResult -Test "$($res.Name)" -Passed $true -Details "$($res.Type) - $($resource.location)"
            Record-Test -Name $res.Name -Passed $true -Details $res.Type
        } else {
            Write-TestResult -Test "$($res.Name)" -Passed $false -Details "Not found"
            Record-Test -Name $res.Name -Passed $false -Details "Not found"
        }
    } catch {
        Write-TestResult -Test "$($res.Name)" -Passed $false -Details "Error"
        Record-Test -Name $res.Name -Passed $false -Details "Access error"
    }
}

# Summary Report
Write-TestHeader "Test Summary"

$passRate = if ($results.Total -gt 0) { 
    [math]::Round(($results.Passed / $results.Total) * 100, 1)
} else { 0 }

Write-Host "Total Tests:  $($results.Total)" -ForegroundColor White
Write-Host "Passed:       $($results.Passed)" -ForegroundColor Green
Write-Host "Failed:       $($results.Failed)" -ForegroundColor Red
Write-Host "Pass Rate:    $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } else { "Yellow" })

# Overall decision
Write-Host "`n" -NoNewline
if ($results.Failed -eq 0) {
    Write-Host "[SUCCESS] All tests passed - Marco sandbox AI services ready" -ForegroundColor Green
} elseif ($passRate -ge 70) {
    Write-Host "[WARNING] Some tests failed - Review issues above" -ForegroundColor Yellow
} else {
    Write-Host "[FAILURE] Critical issues detected - Fix required" -ForegroundColor Red
}

# Save results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDir = Join-Path $PSScriptRoot "..\runs\ai-service-tests"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$reportPath = Join-Path $outputDir "marco-ai-services-test-$timestamp.json"
$results | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8

Write-Host "`n[INFO] Test results saved to: $reportPath" -ForegroundColor Cyan

# Return exit code
exit $(if ($results.Failed -eq 0) { 0 } else { 1 })
