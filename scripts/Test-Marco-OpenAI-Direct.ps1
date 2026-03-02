<#
.SYNOPSIS
    Direct API test of marco-sandbox-openai-v2 GPT-5.1 deployment

.DESCRIPTION
    Makes a simple chat completion request to validate the service is responding
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Testing marco-sandbox-openai-v2" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Configuration
$serviceName = "marco-sandbox-openai-v2"
$resourceGroup = "EsDAICoE-Sandbox"
$deploymentName = "gpt-5.1-chat"
$endpoint = "https://marco-sandbox-openai-v2.openai.azure.com/"

Write-Host "[INFO] Service: $serviceName" -ForegroundColor Yellow
Write-Host "[INFO] Deployment: $deploymentName" -ForegroundColor Yellow
Write-Host "[INFO] Endpoint: $endpoint" -ForegroundColor Yellow
Write-Host ""

# Step 1: Get API key
Write-Host "[STEP 1] Getting API key..." -ForegroundColor Cyan
try {
    $keys = az cognitiveservices account keys list `
        --name $serviceName `
        --resource-group $resourceGroup `
        2>&1 | ConvertFrom-Json
    
    $apiKey = $keys.key1
    Write-Host "[PASS] API key retrieved" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Could not get API key: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Test API endpoint
Write-Host "`n[STEP 2] Testing chat completion API..." -ForegroundColor Cyan

# Try multiple API versions for compatibility
$apiVersions = @("2024-02-15-preview", "2023-12-01-preview", "2023-05-15")
$testPrompt = "Hello! What is 2+2? Please answer in one sentence."

$body = @{
    messages = @(
        @{
            role = "system"
            content = "You are a helpful AI assistant."
        },
        @{
            role = "user"
            content = $testPrompt
        }
    )
    max_tokens = 100
    temperature = 0.7
} | ConvertTo-Json -Depth 10

$headers = @{
    "Content-Type" = "application/json"
    "api-key" = $apiKey
}

Write-Host "[INFO] Sending request: '$testPrompt'" -ForegroundColor Yellow

$response = $null
$successfulApiVersion = $null

foreach ($apiVersion in $apiVersions) {
    $apiUrl = "$endpoint/openai/deployments/$deploymentName/chat/completions?api-version=$apiVersion"
    Write-Host "[INFO] Trying API version: $apiVersion" -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body
        $successfulApiVersion = $apiVersion
        Write-Host "[PASS] API version $apiVersion works!" -ForegroundColor Green
        break
    } catch {
        Write-Host "[INFO] API version $apiVersion failed: $($_.Exception.Message)" -ForegroundColor Gray
        continue
    }
}

if ($response) {
    try {
        # Response received
    
    Write-Host "[PASS] API responded successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor White
    Write-Host "----------------------------------------" -ForegroundColor Gray
    Write-Host $response.choices[0].message.content -ForegroundColor White
    Write-Host "----------------------------------------" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[INFO] API Version: $successfulApiVersion" -ForegroundColor Gray
    Write-Host "[INFO] Model: $($response.model)" -ForegroundColor Gray
    Write-Host "[INFO] Usage: $($response.usage.prompt_tokens) prompt + $($response.usage.completion_tokens) completion = $($response.usage.total_tokens) total tokens" -ForegroundColor Gray
    Write-Host "[INFO] Finish reason: $($response.choices[0].finish_reason)" -ForegroundColor Gray
    
    # Save response
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outputDir = Join-Path $PSScriptRoot "..\runs\openai-tests"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $testResult = @{
        timestamp = $timestamp
        service = $serviceName
        deployment = $deploymentName
        endpoint = $endpoint
        apiVersion = $successfulApiVersion
        prompt = $testPrompt
        response = $response.choices[0].message.content
        model = $response.model
        usage = $response.usage
        success = $true
    }
    
    $reportPath = Join-Path $outputDir "openai-test-$timestamp.json"
    $testResult | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
    
    Write-Host "`n[SUCCESS] Test passed - GPT-5.1 is responding correctly" -ForegroundColor Green
    Write-Host "[INFO] Results saved to: $reportPath" -ForegroundColor Cyan
    
    exit 0
    
} catch {
    Write-Host "[FAIL] Error processing response: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
} else {
    Write-Host "[FAIL] All API versions failed" -ForegroundColor Red
    Write-Host "[INFO] Tried versions: $($apiVersions -join ', ')" -ForegroundColor Yellow
    exit 1
}
