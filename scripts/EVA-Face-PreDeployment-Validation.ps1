#!/usr/bin/env pwsh
<#
.SYNOPSIS
    EVA Face GO/NO-GO Pre-Deployment Validation
    
.DESCRIPTION
    Validates prerequisites for Phase 1 EVA Face Gateway deployment:
    1. Azure connectivity and authentication
    2. Production resource existence validation
    3. Container registry access
    4. Network requirements assessment
    5. RBAC permissions check
    
    This is the GO/NO-GO gate before Phase 1 deployment starts.
    
.PARAMETER SubscriptionId
    Target subscription (default: EsPAICoESub production)
    
.EXAMPLE
    .\EVA-Face-PreDeployment-Validation.ps1
    
.NOTES
    Author: EVA Foundation
    Date: February 3, 2026
    Version: 1.0 - GO/NO-GO Validation
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "802d84ab-3189-4221-8453-fcc30c8dc8ea"  # EsPAICoESub
)

$ErrorActionPreference = "Continue"
Set-StrictMode -Version Latest

# ASCII-only output
$OutputEncoding = [System.Text.Encoding]::ASCII

# Test results
$script:criticalFails = 0
$script:warnings = 0
$script:passes = 0

function Write-TestResult {
    param([string]$Test, [string]$Status, [string]$Message)
    
    $symbol = switch ($Status) {
        "PASS" { "[PASS]"; $script:passes++; "Green" }
        "FAIL" { "[FAIL]"; $script:criticalFails++; "Red" }
        "WARN" { "[WARN]"; $script:warnings++; "Yellow" }
        "INFO" { "[INFO]"; "Cyan" }
    }
    
    Write-Host "$($symbol[0]) $Test" -ForegroundColor $symbol[1]
    if ($Message) {
        Write-Host "       $Message" -ForegroundColor Gray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "EVA FACE GO/NO-GO PRE-DEPLOYMENT VALIDATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Target: EsPAICoESub Production"
Write-Host "Purpose: Phase 1 readiness validation`n"

#region Test 1: Azure CLI Authentication
Write-Host "`n=== TEST 1: Azure CLI Authentication ===" -ForegroundColor Yellow

try {
    $account = az account show --query "{subscription:name, user:user.name}" -o json | ConvertFrom-Json
    Write-TestResult "Azure CLI Login" "PASS" "Logged in as: $($account.user)"
    Write-TestResult "Current Subscription" "INFO" "$($account.subscription)"
} catch {
    Write-TestResult "Azure CLI Login" "FAIL" "Not logged in - Run: az login"
    $script:criticalFails++
}

#endregion

#region Test 2: Production Subscription Access
Write-Host "`n=== TEST 2: Production Subscription Access ===" -ForegroundColor Yellow

try {
    az account set --subscription $SubscriptionId -o none 2>&1 | Out-Null
    $sub = az account show --query "{name:name, id:id, state:state}" -o json | ConvertFrom-Json
    
    if ($sub.state -eq "Enabled") {
        Write-TestResult "EsPAICoESub Access" "PASS" "Subscription enabled"
    } else {
        Write-TestResult "EsPAICoESub Access" "FAIL" "Subscription state: $($sub.state)"
    }
} catch {
    Write-TestResult "EsPAICoESub Access" "FAIL" "Cannot access subscription"
}

#endregion

#region Test 3: EVA Chat Production Resources
Write-Host "`n=== TEST 3: EVA Chat Production Resources ===" -ForegroundColor Yellow

$evachatResources = @{
    "EVAChatPrdRg" = @("Microsoft.ContainerRegistry/registries", "Microsoft.Storage/storageAccounts", "Microsoft.Cache/Redis")
}

foreach ($rg in $evachatResources.Keys) {
    $exists = az group exists --name $rg
    if ($exists -eq "true") {
        Write-TestResult "Resource Group: $rg" "PASS" "Exists"
        
        foreach ($resourceType in $evachatResources[$rg]) {
            $count = (az resource list --resource-group $rg --resource-type $resourceType --query "length([])" -o tsv)
            if ([int]$count -gt 0) {
                Write-TestResult "  -> $($resourceType.Split('/')[-1])" "PASS" "$count resource(s)"
            } else {
                Write-TestResult "  -> $($resourceType.Split('/')[-1])" "WARN" "No resources found"
            }
        }
    } else {
        Write-TestResult "Resource Group: $rg" "FAIL" "Does not exist"
    }
}

#endregion

#region Test 4: EVA Domain Assistant Production Resources
Write-Host "`n=== TEST 4: EVA Domain Assistant Production Resources ===" -ForegroundColor Yellow

$infoasstResources = @{
    "infoasst-prd1" = @("Microsoft.Web/sites", "Microsoft.Search/searchServices", "Microsoft.DocumentDB/databaseAccounts")
}

foreach ($rg in $infoasstResources.Keys) {
    $exists = az group exists --name $rg
    if ($exists -eq "true") {
        Write-TestResult "Resource Group: $rg" "PASS" "Exists"
        
        foreach ($resourceType in $infoasstResources[$rg]) {
            $count = (az resource list --resource-group $rg --resource-type $resourceType --query "length([])" -o tsv)
            if ([int]$count -gt 0) {
                Write-TestResult "  -> $($resourceType.Split('/')[-1])" "PASS" "$count resource(s)"
            } else {
                Write-TestResult "  -> $($resourceType.Split('/')[-1])" "WARN" "No resources found"
            }
        }
    } else {
        Write-TestResult "Resource Group: $rg" "FAIL" "Does not exist"
    }
}

#endregion

#region Test 5: Container Registry Access
Write-Host "`n=== TEST 5: Container Registry Access ===" -ForegroundColor Yellow

$acr = "evachatprdacr"
try {
    $acrInfo = az acr show --name $acr --query "{loginServer:loginServer, sku:sku.name}" -o json 2>$null | ConvertFrom-Json
    Write-TestResult "ACR Exists" "PASS" "$($acrInfo.loginServer)"
    Write-TestResult "ACR SKU" "INFO" "$($acrInfo.sku)"
    
    # Test if we can list repos (requires AcrPull or higher)
    $repos = az acr repository list --name $acr --query "length([])" -o tsv 2>$null
    if ($repos -match '^\d+$') {
        Write-TestResult "ACR Access (Read)" "PASS" "$repos repositories visible"
    } else {
        Write-TestResult "ACR Access (Read)" "WARN" "Cannot list repositories (needs AcrPull role)"
    }
    
    # Test if we can push (requires AcrPush)
    $canPush = az role assignment list --scope "/subscriptions/$SubscriptionId/resourceGroups/EVAChatPrdRg/providers/Microsoft.ContainerRegistry/registries/$acr" --assignee "marco.presta@hrsdc-rhdcc.gc.ca" --query "[?contains(roleDefinitionName, 'Push') || contains(roleDefinitionName, 'Contributor') || contains(roleDefinitionName, 'Owner')].roleDefinitionName" -o tsv 2>$null
    
    if ($canPush) {
        Write-TestResult "ACR Access (Push)" "PASS" "Can push images (role: $canPush)"
    } else {
        Write-TestResult "ACR Access (Push)" "WARN" "Cannot push images (needs AcrPush role)"
    }
} catch {
    Write-TestResult "Container Registry" "FAIL" "Cannot access $acr"
}

#endregion

#region Test 6: Container Apps Environment
Write-Host "`n=== TEST 6: Container Apps Environment ===" -ForegroundColor Yellow

$envName = "evachatprd-appenv"
try {
    $env = az containerapp env show --name $envName --resource-group EVAChatPrdRg --query "{name:name, provisioningState:properties.provisioningState}" -o json 2>$null | ConvertFrom-Json
    
    if ($env.provisioningState -eq "Succeeded") {
        Write-TestResult "Container Apps Environment" "PASS" "$envName is ready"
    } else {
        Write-TestResult "Container Apps Environment" "WARN" "State: $($env.provisioningState)"
    }
} catch {
    Write-TestResult "Container Apps Environment" "FAIL" "Cannot access $envName"
}

#endregion

#region Test 7: RBAC Permissions Assessment
Write-Host "`n=== TEST 7: RBAC Permissions Assessment ===" -ForegroundColor Yellow

$user = "marco.presta@hrsdc-rhdcc.gc.ca"
$roles = az role assignment list --assignee $user --subscription $SubscriptionId --query "[].{role:roleDefinitionName, scope:scope}" -o json 2>$null | ConvertFrom-Json

if ($roles) {
    Write-TestResult "RBAC Assignments" "PASS" "$($roles.Count) role(s) assigned"
    
    $hasContributor = $roles | Where-Object { $_.role -match "Contributor|Owner" }
    $hasWebAppContributor = $roles | Where-Object { $_.role -match "Website Contributor" }
    
    if ($hasContributor) {
        Write-TestResult "  -> Deployment Rights" "PASS" "Has Contributor/Owner role"
    } elseif ($hasWebAppContributor) {
        Write-TestResult "  -> Deployment Rights" "PASS" "Has Website Contributor role"
    } else {
        Write-TestResult "  -> Deployment Rights" "WARN" "Limited permissions - may need elevation"
    }
} else {
    Write-TestResult "RBAC Assignments" "WARN" "No roles found at subscription level"
}

#endregion

#region Test 8: Network Connectivity Assessment
Write-Host "`n=== TEST 8: Network Connectivity Assessment ===" -ForegroundColor Yellow

Write-TestResult "Network Location" "INFO" "Machine: $env:COMPUTERNAME"

# Test public endpoint connectivity (should work)
try {
    $response = Invoke-WebRequest -Uri "https://evachatprdsa.blob.core.windows.net" -Method HEAD -TimeoutSec 5 -ErrorAction Stop
    Write-TestResult "Azure Storage (Public)" "PASS" "Can reach Azure public endpoints"
} catch {
    Write-TestResult "Azure Storage (Public)" "WARN" "Cannot reach public endpoints - Check network"
}

# Test private endpoint (will likely fail from workstation)
try {
    $response = Invoke-WebRequest -Uri "https://prdchat.eva-ave-prv" -Method HEAD -TimeoutSec 5 -ErrorAction Stop
    Write-TestResult "EVA Chat (Private)" "PASS" "Can reach private endpoints - ON VNET"
} catch {
    if ($_.Exception.Message -like "*403*" -or $_.Exception.Message -like "*could not be resolved*") {
        Write-TestResult "EVA Chat (Private)" "INFO" "Cannot reach (expected - requires HCCLD2 VNet access)"
    } else {
        Write-TestResult "EVA Chat (Private)" "WARN" "Network error: $($_.Exception.Message)"
    }
}

#endregion

#region Test 9: Required Tools & SDKs
Write-Host "`n=== TEST 9: Required Tools & SDKs ===" -ForegroundColor Yellow

# Azure CLI
$azVersion = az version --query '\"azure-cli\"' -o tsv 2>$null
if ($azVersion) {
    Write-TestResult "Azure CLI" "PASS" "Version: $azVersion"
} else {
    Write-TestResult "Azure CLI" "FAIL" "Not installed"
}

# Docker (for local build)
$dockerVersion = docker --version 2>$null
if ($dockerVersion) {
    Write-TestResult "Docker" "PASS" "$dockerVersion"
} else {
    Write-TestResult "Docker" "WARN" "Not installed (optional for local build)"
}

# Python (for local dev)
$pythonVersion = python --version 2>$null
if ($pythonVersion) {
    Write-TestResult "Python" "PASS" "$pythonVersion"
} else {
    Write-TestResult "Python" "WARN" "Not installed (optional for local dev)"
}

#endregion

#region GO/NO-GO Decision
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "GO/NO-GO DECISION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Test Summary:"
Write-Host "  [PASS] Passing tests: $script:passes" -ForegroundColor Green
Write-Host "  [WARN] Warnings: $script:warnings" -ForegroundColor Yellow
Write-Host "  [FAIL] Critical failures: $script:criticalFails" -ForegroundColor Red

Write-Host "`n"

if ($script:criticalFails -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " DECISION: GO FOR PHASE 1 DEPLOYMENT" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nAll critical prerequisites met. Ready to proceed with EVA Face Gateway deployment."
    
    if ($script:warnings -gt 0) {
        Write-Host "`nWARNINGS: $script:warnings non-critical issues detected (see above)"
        Write-Host "These can be addressed during deployment."
    }
    
    Write-Host "`nNext Steps:"
    Write-Host "  1. Review PRODUCTION-READY-GO-DECISION.md"
    Write-Host "  2. Build EVA Face Gateway code"
    Write-Host "  3. Deploy to Container Apps (evachatprd-appenv)"
    Write-Host "  4. Test from DevOps VM (AICoE-devops-prd01)"
    
    exit 0
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host " DECISION: NO-GO - FIX CRITICAL ISSUES" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "`n$script:criticalFails critical issue(s) must be resolved before deployment."
    Write-Host "`nReview failed tests above and address each issue."
    Write-Host "Then re-run this validation script."
    
    exit 1
}

#endregion
