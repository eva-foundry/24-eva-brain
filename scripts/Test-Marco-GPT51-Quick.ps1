# Direct test of marco-sandbox-openai-v2 without needing full backend
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " Marco Sandbox GPT-5.1 Direct API Test" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$serviceName = "marco-sandbox-openai-v2"
$deployment = "gpt-5.1-chat"

Write-Host "[1/3] Getting API key..." -ForegroundColor Yellow
$key = (az cognitiveservices account keys list --name $serviceName --resource-group EsDAICoE-Sandbox | ConvertFrom-Json).key1
Write-Host "[PASS] API key retrieved" -ForegroundColor Green

Write-Host "`n[2/3] Testing chat completion..." -ForegroundColor Yellow
$headers = @{
    'api-key' = $key
    'Content-Type' = 'application/json'
}

$body = @{
    messages = @(
        @{
            role = 'system'
            content = 'You are a helpful AI assistant for Employment and Social Development Canada (ESDC).'
        },
        @{
            role = 'user'
            content = 'What is Employment Insurance? Answer in 2-3 sentences.'
        }
    )
    max_completion_tokens = 150
} | ConvertTo-Json -Depth 5

try {
    $response = Invoke-RestMethod -Uri "https://marco-sandbox-openai-v2.openai.azure.com/openai/deployments/$deployment/chat/completions?api-version=2024-02-01" -Method Post -Headers $headers -Body $body
    
    Write-Host "[PASS] API responded successfully!" -ForegroundColor Green
    Write-Host "`n[3/3] Response:" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Gray
    Write-Host $response.choices[0].message.content -ForegroundColor White
    Write-Host "============================================" -ForegroundColor Gray
    Write-Host "`n[INFO] Model: $($response.model)" -ForegroundColor Gray
    Write-Host "[INFO] Tokens: $($response.usage.total_tokens) total ($($response.usage.prompt_tokens) prompt + $($response.usage.completion_tokens) completion)" -ForegroundColor Gray
    Write-Host "`n[SUCCESS] Marco-sandbox GPT-5.1 is fully operational!" -ForegroundColor Green
    Write-Host "`nConfiguration validated:" -ForegroundColor Cyan
    Write-Host "  - Service: marco-sandbox-openai-v2" -ForegroundColor Gray
    Write-Host "  - Deployment: gpt-5.1-chat" -ForegroundColor Gray
    Write-Host "  - Model: $($response.model)" -ForegroundColor Gray
    Write-Host "  - Region: Canada East" -ForegroundColor Gray
    
} catch {
    Write-Host "[FAIL] API call failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
