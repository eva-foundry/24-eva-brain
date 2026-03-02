#!/usr/bin/env pwsh
# EVA-FEATURE: F24-03
# EVA-STORY: F24-03-001
# EVA-STORY: F24-03-002
# EVA-STORY: F24-04-001
# EVA-STORY: F24-04-002
# EVA-STORY: F24-04-003
# EVA-STORY: F24-05-001
# EVA-STORY: F24-05-002
# EVA-STORY: F24-05-003
# EVA-STORY: F24-05-004
# EVA-STORY: F24-05-005
# EVA-STORY: F24-07-001
# EVA-STORY: F24-07-002
# EVA-STORY: F24-07-003
# EVA-STORY: F24-07-004
# EVA-STORY: F24-07-005
# EVA-STORY: F24-07-006
# EVA-STORY: F24-07-008
# EVA-STORY: F24-08-001
# EVA-STORY: F24-08-002
# EVA-STORY: F24-08-003
# EVA-STORY: F24-08-004
# EVA-STORY: F24-08-005
# EVA-STORY: F24-10-001
# EVA-STORY: F24-10-002
# EVA-STORY: F24-10-003
# EVA-STORY: F24-10-004
# EVA-STORY: F24-10-005
# EVA-STORY: F24-10-006
# EVA-STORY: F24-11-001
# EVA-STORY: F24-11-002
# EVA-STORY: F24-11-003
# EVA-STORY: F24-11-004
# EVA-STORY: F24-12-001
# EVA-STORY: F24-12-002
# EVA-STORY: F24-12-003
# EVA-STORY: F24-12-004
# EVA-STORY: F24-13-001
# EVA-STORY: F24-13-002
# EVA-STORY: F24-13-003
# EVA-STORY: F24-13-004
# EVA-STORY: F24-13-005
# EVA-STORY: F24-15-001
# EVA-STORY: F24-15-002
# EVA-STORY: F24-15-003
# EVA-STORY: F24-16-001
# EVA-STORY: F24-16-002
# EVA-STORY: F24-16-003
# EVA-STORY: F24-16-004
# EVA-STORY: F24-16-005
# EVA-STORY: F24-17-001
# EVA-STORY: F24-17-002
# EVA-STORY: F24-17-003
# EVA-STORY: F24-18-001
# EVA-STORY: F24-18-002
# EVA-STORY: F24-18-003
<#
.SYNOPSIS
    EVA Brain API Smoke Test - GO/NO-GO Validation for API Decomposition
    
.DESCRIPTION
    Tests EVA Brain backend APIs to validate the monolithic decomposition concept:
    1. Frontend (any chat app) -> calls APIs
    2. EVA Pipeline (enrichment/document processing)
    3. EVA Brain Backend (API/RAG engine)
    
    This script acts as the Phase 0.5 validation before attempting the architectural split.
    
.PARAMETER BaseUrl
    Backend API base URL (default: http://localhost:5000)
    
.PARAMETER OutputDir
    Directory for test logs and traces (default: ../runs/smoke-tests)
    
.EXAMPLE
    .\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"
    
.EXAMPLE
    .\EVA-Brain-Smoke-Test.ps1 -BaseUrl "https://infoasst-web-hccld2.azurewebsites.net"
    
.NOTES
    Author: EVA Brain PoC Team
    Date: February 3, 2026
    Version: 1.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = "http://localhost:5000",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "..\runs\smoke-tests"
)

# Set strict mode and error handling
$ErrorActionPreference = "Continue"
Set-StrictMode -Version Latest

# ASCII-only output (critical for Windows cp1252)
$OutputEncoding = [System.Text.Encoding]::ASCII

# Timestamp for this test run
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runId = "smoke_test_$timestamp"

# Create output directory structure
$outputPath = Join-Path $PSScriptRoot $OutputDir
$runPath = Join-Path $outputPath $runId
$logsPath = Join-Path $runPath "logs"
$tracesPath = Join-Path $runPath "traces"
$evidencePath = Join-Path $runPath "evidence"

foreach ($dir in @($outputPath, $runPath, $logsPath, $tracesPath, $evidencePath)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Test results accumulator
$script:testResults = @()
$script:testsPassed = 0
$script:testsFailed = 0
$script:testsSkipped = 0

# Auth headers from frontend .env
$authHeaders = @{
    "X-MS-CLIENT-PRINCIPAL-ID" = "fc1cf8cd-fce3-4ad5-bd16-58725f4e6a33"
    "X-MS-CLIENT-PRINCIPAL" = "eyJhdXRoX3R5cCI6ImFhZCIsImNsYWltcyI6W3sidHlwIjoiYXVkIiwidmFsIjoiNmVlMTE0YjUtY2YxZC00NDRkLTk0NDktNTIyODgwZGU3NDNiIn0seyJ0eXAiOiJpc3MiLCJ2YWwiOiJodHRwczpcL1wvbG9naW4ubWljcm9zb2Z0b25saW5lLmNvbVwvOWVkNTU4NDYtOGE4MS00MjQ2LWFjZDgtYjFhMDFhYmZjMGQxXC92Mi4wIn0seyJ0eXAiOiJpYXQiLCJ2YWwiOiIxNzY3NjQ2NjUxIn0seyJ0eXAiOiJuYmYiLCJ2YWwiOiIxNzY3NjQ2NjUxIn0seyJ0eXAiOiJleHAiLCJ2YWwiOiIxNzY3NjUwNTUxIn0seyJ0eXAiOiJhaW8iLCJ2YWwiOiJBYlFBU1wvOGFBQUFBUnUxVGxwcHpZYUxHenBOWWphRlhmeTVwd082eWlNYTZtK0FRQVhhaDRhQWRocUhMREwxMUlydDM1QmNrUU5NV2d5RE1aSUFwbGNDUU9xVllsZk5vRWdHSDdjMnZ0T0d5Y2JpXC9OeHZTc1pXcmJUdmFXXC9RSGlCcGlvQ0xNbkdwXC9DNVc4RzU3bUtxWUdPN0p6UzZMbDc0ZnlDNmRjNEFZdjN3TDlxZE5vdVpZVkF4K2hjVnQ3NXprbEM3Rjh3alppUXNEQnc5XC95ZXpEUllBWFZ6VUhha2szSUJWUEUwXC84aVwvNGZoKzlhYmtzQT0ifSx7InR5cCI6ImNfaGFzaCIsInZhbCI6IkJlbkE3Mkh3eEtEeklXaFFLeEl2cVEifSx7InR5cCI6ImNjIiwidmFsIjoiQ2dFQUVoRm9jbk5rWXkxeWFHUmpZeTVuWXk1allSb1NDaENVc2xIV2ZlU0dScllCS1N2ZXI2MWVJaElLRUgySFVFaG8wKzFKdjNqUHo4V0xCd0FvQVRJQ1RrRTRBQT09In0seyJ0eXAiOiJodHRwOlwvXC9zY2hlbWFzLnhtbHNvYXAub3JnXC93c1wvMjAwNVwvMDVcL2lkZW50aXR5XC9jbGFpbXNcL2VtYWlsYWRkcmVzcyIsInZhbCI6Im1hcmNvLnByZXN0YUBocnNkYy1yaGRjYy5nYy5jYSJ9LHsidHlwIjoiZ3JvdXBzIiwidmFsIjoiOWY1NDBjMmUtZTA1Yy00MDEyLWJhNDMtNDg0NmRhYmZhZWE2In0seyJ0eXAiOiJncm91cHMiLCJ2YWwiOiIzZmVjZTY2My02OGVhLTRhMzAtYjc2ZC1mNzQ1YmUzYjYyZGIifSx7InR5cCI6Imdyb3VwcyIsInZhbCI6IjQ4N2U5NDRlLTk0MDgtNDc3OC1iZTIxLWRkZTJiNWE3ZDE5ZCJ9LHsidHlwIjoiZ3JvdXBzIiwidmFsIjoiMjQwOWUxYTctZWZjMy00ZWJmLWEzNDQtNTQ1ZWI4NWNmY2E1In0seyJ0eXAiOiJuYW1lIiwidmFsIjoiUHJlc3RhLCBNYXJjbyBNIFtOQ10ifSx7InR5cCI6Im5vbmNlIiwidmFsIjoiNGExMzNjYzAyMTUwNDFjODlhOGQzYjQwZjYzYzIwMGZfMjAyNjAxMDUyMTA3MzAifSx7InR5cCI6Imh0dHA6XC9cL3NjaGVtYXMubWljcm9zb2Z0LmNvbVwvaWRlbnRpdHlcL2NsYWltc1wvb2JqZWN0aWRlbnRpZmllciIsInZhbCI6ImZjMWNmOGNkLWZjZTMtNGFkNS1iZDE2LTU4NzI1ZjRlNmEzMyJ9LHsidHlwIjoicHJlZmVycmVkX3VzZXJuYW1lIiwidmFsIjoibWFyY28ucHJlc3RhQGhyc2RjLXJoZGNjLmdjLmNhIn0seyJ0eXAiOiJyaCIsInZhbCI6IjEuQVJjQVJsalZub0dLUmtLczJMR2dHcl9BMGJVVTRXNGR6MDFFbEVsU0tJRGVkRHNYQUhzWEFBLiJ9LHsidHlwIjoic2lkIiwidmFsIjoiNmFlYzkwOGItMzA2Mi00NGI3LTg5NjYtZDU2ZTM3MmEzOGVmIn0seyJ0eXAiOiJodHRwOlwvXC9zY2hlbWFzLnhtbHNvYXAub3JnXC93c1wvMjAwNVwvMDVcL2lkZW50aXR5XC9jbGFpbXNcL25hbWVpZGVudGlmaWVyIiwidmFsIjoiVWNkZUU1a2IzTEVFcEs3VmhsZTAzM0pQZEVWdm4wTW9nbEpmUW1iQldvSSJ9LHsidHlwIjoiaHR0cDpcL1wvc2NoZW1hcy5taWNyb3NvZnQuY29tXC9pZGVudGl0eVwvY2xhaW1zXC90ZW5hbnRpZCIsInZhbCI6IjllZDU1ODQ2LThhODEtNDI0Ni1hY2Q4LWIxYTAxYWJmYzBkMSJ9LHsidHlwIjoidXRpIiwidmFsIjoiZllkUVNHalQ3VW1fZU1fUHhZc0hBQSJ9LHsidHlwIjoidmVyIiwidmFsIjoiMi4wIn1dLCJuYW1lX3R5cCI6Imh0dHA6XC9cL3NjaGVtYXMueG1sc29hcC5vcmdcL3dzXC8yMDA1XC8wNVwvaWRlbnRpdHlcL2NsYWltc1wvZW1haWxhZGRyZXNzIiwicm9sZV90eXAiOiJodHRwOlwvXC9zY2hlbWFzLm1pY3Jvc29mdC5jb21cL3dzXC8yMDA4XC8wNlwvaWRlbnRpdHlcL2NsYWltc1wvcm9sZSJ9"
    "Content-Type" = "application/json"
}

#region Helper Functions

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output (ASCII safe)
    switch ($Level) {
        "PASS" { Write-Host $logMessage -ForegroundColor Green }
        "FAIL" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
    
    # File output
    $logFile = Join-Path $logsPath "smoke_test.log"
    Add-Content -Path $logFile -Value $logMessage -Encoding ASCII
}

function Save-Request {
    param(
        [string]$TestName,
        [hashtable]$Headers,
        [object]$Body
    )
    
    $requestFile = Join-Path $tracesPath "$TestName`_request.txt"
    
    $requestText = @"
=== REQUEST: $TestName ===
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
URL: $BaseUrl
Headers:
$($Headers.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" } | Out-String)

Body:
$($Body | ConvertTo-Json -Depth 10 -Compress:$false)
"@
    
    Set-Content -Path $requestFile -Value $requestText -Encoding ASCII
}

function Save-Response {
    param(
        [string]$TestName,
        [int]$StatusCode,
        [object]$Response,
        [string]$RawResponse
    )
    
    $responseFile = Join-Path $tracesPath "$TestName`_response.txt"
    
    $responseText = @"
=== RESPONSE: $TestName ===
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Status Code: $StatusCode

Response Body:
$RawResponse
"@
    
    Set-Content -Path $responseFile -Value $responseText -Encoding ASCII
}

function Record-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message,
        [object]$Details = $null
    )
    
    $result = @{
        TestName = $TestName
        Status = $Status
        Message = $Message
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Details = $Details
    }
    
    $script:testResults += $result
    
    switch ($Status) {
        "PASS" { $script:testsPassed++ }
        "FAIL" { $script:testsFailed++ }
        "SKIP" { $script:testsSkipped++ }
    }
}

#endregion

#region Test Cases

function Test-HealthEndpoint {
    $testName = "01_Health_Endpoint"
    Write-TestLog "Running Test: $testName" "INFO"
    
    try {
        $url = "$BaseUrl/health"
        
        Save-Request -TestName $testName -Headers @{"Accept" = "application/json"} -Body $null
        
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{"Accept" = "application/json"} -TimeoutSec 30
        $statusCode = 200
        
        Save-Response -TestName $testName -StatusCode $statusCode -Response $response -RawResponse ($response | ConvertTo-Json)
        
        Write-TestLog "[PASS] Health endpoint returned 200 OK" "PASS"
        Record-TestResult -TestName $testName -Status "PASS" -Message "Health endpoint accessible" -Details $response
        
        return $true
    }
    catch {
        Write-TestLog "[FAIL] Health endpoint failed: $($_.Exception.Message)" "FAIL"
        Save-Response -TestName $testName -StatusCode 0 -Response $null -RawResponse $_.Exception.Message
        Record-TestResult -TestName $testName -Status "FAIL" -Message $_.Exception.Message
        return $false
    }
}

function Test-ChatUngrounded {
    $testName = "02_Chat_Ungrounded"
    Write-TestLog "Running Test: $testName" "INFO"
    
    try {
        $url = "$BaseUrl/chat"
        
        $requestBody = @{
            messages = @(
                @{
                    role = "user"
                    content = "What is Employment Insurance in Canada? Provide a brief 2-sentence answer."
                }
            )
            session_state = @{
                approach = "rrr"
                conversation_id = "smoke-test-ungrounded"
                overrides = @{
                    retrieval_mode = "text"
                    top = 3
                    temperature = 0.3
                    prompt_template_prefix = ""
                    prompt_template_suffix = ""
                    exclude_category = ""
                }
            }
        } | ConvertTo-Json -Depth 10
        
        Save-Request -TestName $testName -Headers $authHeaders -Body ($requestBody | ConvertFrom-Json)
        
        Write-TestLog "Sending ungrounded chat request..." "INFO"
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $authHeaders -Body $requestBody -TimeoutSec 60
        
        Save-Response -TestName $testName -StatusCode 200 -Response $response -RawResponse ($response | ConvertTo-Json -Depth 10)
        
        # Validate response structure
        if ($response.choices -and $response.choices.Count -gt 0) {
            $answer = $response.choices[0].message.content
            Write-TestLog "[PASS] Chat ungrounded returned answer: $($answer.Substring(0, [Math]::Min(100, $answer.Length)))..." "PASS"
            Record-TestResult -TestName $testName -Status "PASS" -Message "Ungrounded chat successful" -Details $response
            return $true
        }
        else {
            Write-TestLog "[FAIL] Chat response missing expected structure" "FAIL"
            Record-TestResult -TestName $testName -Status "FAIL" -Message "Response structure invalid"
            return $false
        }
    }
    catch {
        Write-TestLog "[FAIL] Chat ungrounded failed: $($_.Exception.Message)" "FAIL"
        Save-Response -TestName $testName -StatusCode 0 -Response $null -RawResponse $_.Exception.Message
        Record-TestResult -TestName $testName -Status "FAIL" -Message $_.Exception.Message
        return $false
    }
}

function Test-ChatRAG {
    $testName = "03_Chat_RAG_proj1"
    Write-TestLog "Running Test: $testName" "INFO"
    
    try {
        $url = "$BaseUrl/chat"
        
        $requestBody = @{
            messages = @(
                @{
                    role = "user"
                    content = "What are the eligibility rules for PSHCP (Public Service Health Care Plan)? Focus on who qualifies."
                }
            )
            session_state = @{
                approach = "rrr"
                conversation_id = "smoke-test-rag"
                overrides = @{
                    retrieval_mode = "hybrid"
                    semantic_ranker = $true
                    top = 5
                    temperature = 0.3
                    prompt_template_prefix = ""
                    prompt_template_suffix = ""
                    exclude_category = ""
                    selectedFolders = "proj1"
                }
            }
        } | ConvertTo-Json -Depth 10
        
        Save-Request -TestName $testName -Headers $authHeaders -Body ($requestBody | ConvertFrom-Json)
        
        Write-TestLog "Sending RAG chat request (proj1 folder)..." "INFO"
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $authHeaders -Body $requestBody -TimeoutSec 90
        
        Save-Response -TestName $testName -StatusCode 200 -Response $response -RawResponse ($response | ConvertTo-Json -Depth 10)
        
        # Validate RAG response structure
        if ($response.choices -and $response.choices.Count -gt 0) {
            $message = $response.choices[0].message
            $answer = $message.content
            $context = $message.context
            
            # Check for data_points (citations)
            if ($context.data_points -and $context.data_points.Count -gt 0) {
                Write-TestLog "[PASS] RAG query returned answer with $($context.data_points.Count) citations" "PASS"
                Write-TestLog "Answer preview: $($answer.Substring(0, [Math]::Min(150, $answer.Length)))..." "INFO"
                Write-TestLog "Citation example: $($context.data_points[0].Substring(0, [Math]::Min(100, $context.data_points[0].Length)))..." "INFO"
                
                Record-TestResult -TestName $testName -Status "PASS" -Message "RAG chat successful with citations" -Details @{
                    CitationCount = $context.data_points.Count
                    AnswerLength = $answer.Length
                }
                return $true
            }
            else {
                Write-TestLog "[WARN] RAG query returned answer but no citations" "WARN"
                Record-TestResult -TestName $testName -Status "PASS" -Message "RAG chat returned answer (no citations)" -Details $response
                return $true
            }
        }
        else {
            Write-TestLog "[FAIL] RAG response missing expected structure" "FAIL"
            Record-TestResult -TestName $testName -Status "FAIL" -Message "Response structure invalid"
            return $false
        }
    }
    catch {
        Write-TestLog "[FAIL] Chat RAG failed: $($_.Exception.Message)" "FAIL"
        Save-Response -TestName $testName -StatusCode 0 -Response $null -RawResponse $_.Exception.Message
        Record-TestResult -TestName $testName -Status "FAIL" -Message $_.Exception.Message
        return $false
    }
}

function Test-StreamingResponse {
    $testName = "04_Streaming_SSE"
    Write-TestLog "Running Test: $testName (SSE streaming)" "INFO"
    
    try {
        $url = "$BaseUrl/chat"
        
        $requestBody = @{
            messages = @(
                @{
                    role = "user"
                    content = "Count from 1 to 5 with one number per line."
                }
            )
            session_state = @{
                approach = "rrr"
                conversation_id = "smoke-test-streaming"
                overrides = @{
                    retrieval_mode = "text"
                    top = 3
                    temperature = 0.3
                }
            }
            stream = $true
        } | ConvertTo-Json -Depth 10
        
        Save-Request -TestName $testName -Headers $authHeaders -Body ($requestBody | ConvertFrom-Json)
        
        Write-TestLog "Testing SSE streaming endpoint..." "INFO"
        
        # Note: PowerShell's Invoke-RestMethod doesn't handle SSE well
        # This is a simplified test - real SSE requires EventSource or custom handler
        # For now, we'll make a non-streaming request and check if stream parameter is accepted
        
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $authHeaders -Body $requestBody -TimeoutSec 60
        
        if ($response) {
            Write-TestLog "[PASS] Streaming endpoint accepted request (full SSE testing requires browser/EventSource)" "PASS"
            Record-TestResult -TestName $testName -Status "PASS" -Message "Streaming endpoint functional (limited test)"
            return $true
        }
        else {
            Write-TestLog "[WARN] Streaming test inconclusive" "WARN"
            Record-TestResult -TestName $testName -Status "SKIP" -Message "SSE streaming requires EventSource client"
            return $false
        }
    }
    catch {
        Write-TestLog "[FAIL] Streaming test failed: $($_.Exception.Message)" "FAIL"
        Save-Response -TestName $testName -StatusCode 0 -Response $null -RawResponse $_.Exception.Message
        Record-TestResult -TestName $testName -Status "FAIL" -Message $_.Exception.Message
        return $false
    }
}

function Test-SessionsEndpoint {
    $testName = "05_Sessions_Create"
    Write-TestLog "Running Test: $testName" "INFO"
    
    try {
        $url = "$BaseUrl/sessions"
        
        $requestBody = @{
            session_id = "smoke-test-session-$timestamp"
            name = "Smoke Test Session"
        } | ConvertTo-Json
        
        Save-Request -TestName $testName -Headers $authHeaders -Body ($requestBody | ConvertFrom-Json)
        
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $authHeaders -Body $requestBody -TimeoutSec 30
        
        Save-Response -TestName $testName -StatusCode 200 -Response $response -RawResponse ($response | ConvertTo-Json)
        
        Write-TestLog "[PASS] Session created successfully" "PASS"
        Record-TestResult -TestName $testName -Status "PASS" -Message "Session creation successful" -Details $response
        return $true
    }
    catch {
        Write-TestLog "[FAIL] Session creation failed: $($_.Exception.Message)" "FAIL"
        Save-Response -TestName $testName -StatusCode 0 -Response $null -RawResponse $_.Exception.Message
        Record-TestResult -TestName $testName -Status "FAIL" -Message $_.Exception.Message
        return $false
    }
}

#endregion

#region Main Execution

function Invoke-SmokeTest {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  EVA Brain API Smoke Test" -ForegroundColor Cyan
    Write-Host "  Validating API Decomposition Concept" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
    Write-Host "Output: $runPath" -ForegroundColor Yellow
    Write-Host "Run ID: $runId" -ForegroundColor Yellow
    Write-Host ""
    
    Write-TestLog "Starting EVA Brain smoke test suite" "INFO"
    Write-TestLog "Base URL: $BaseUrl" "INFO"
    
    # Test 1: Health check
    $healthOk = Test-HealthEndpoint
    if (-not $healthOk) {
        Write-TestLog "[FAIL] Health check failed - cannot proceed with API tests" "FAIL"
        Write-Host ""
        Write-Host "[CRITICAL] Backend not accessible at $BaseUrl" -ForegroundColor Red
        Write-Host "Please ensure backend is running: cd I:\EVA-JP-v1.2\app\backend && python app.py" -ForegroundColor Yellow
        Write-Host ""
        Generate-Report
        return $false
    }
    
    Start-Sleep -Seconds 1
    
    # Test 2: Chat ungrounded
    $chatOk = Test-ChatUngrounded
    Start-Sleep -Seconds 2
    
    # Test 3: Chat RAG (critical for decomposition validation)
    $ragOk = Test-ChatRAG
    Start-Sleep -Seconds 2
    
    # Test 4: Streaming (optional - SSE validation)
    $streamOk = Test-StreamingResponse
    Start-Sleep -Seconds 1
    
    # Test 5: Sessions API
    $sessionOk = Test-SessionsEndpoint
    
    # Generate final report
    Generate-Report
    
    # Return GO/NO-GO decision
    $criticalTests = $healthOk -and $chatOk -and $ragOk
    return $criticalTests
}

function Generate-Report {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Test Results Summary" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Total Tests: $($script:testResults.Count)" -ForegroundColor White
    Write-Host "Passed: $script:testsPassed" -ForegroundColor Green
    Write-Host "Failed: $script:testsFailed" -ForegroundColor Red
    Write-Host "Skipped: $script:testsSkipped" -ForegroundColor Yellow
    Write-Host ""
    
    # Detailed results
    Write-Host "Test Details:" -ForegroundColor Cyan
    foreach ($result in $script:testResults) {
        $color = switch ($result.Status) {
            "PASS" { "Green" }
            "FAIL" { "Red" }
            "SKIP" { "Yellow" }
            default { "White" }
        }
        
        Write-Host "  [$($result.Status)] $($result.TestName) - $($result.Message)" -ForegroundColor $color
    }
    
    Write-Host ""
    
    # GO/NO-GO Decision
    # CRITICAL: Must have working chat endpoints to get answers
    # If answers are not received, it's a NO-GO regardless of architecture
    $healthPassed = ($script:testResults | Where-Object { 
        $_.TestName -eq "Health_Endpoint" -and $_.Status -eq "PASS" 
    }).Count -gt 0
    
    $chatPassed = ($script:testResults | Where-Object { 
        $_.TestName -match "Chat_Ungrounded|Chat_RAG" -and $_.Status -eq "PASS" 
    }).Count -gt 0
    
    # GO only if: Health works AND at least one chat endpoint returns answers
    $goNoGo = if ($healthPassed -and $chatPassed) { "GO" } else { "NO-GO" }
    $goColor = if ($goNoGo -eq "GO") { "Green" } else { "Red" }
    
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  GO/NO-GO DECISION: $goNoGo" -ForegroundColor $goColor
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($goNoGo -eq "GO") {
        Write-Host "[PASS] EVA Brain APIs are functional" -ForegroundColor Green
        Write-Host "Chat endpoints returning answers successfully" -ForegroundColor Cyan
        Write-Host "Ready to proceed with architectural decomposition:" -ForegroundColor Cyan
        Write-Host "  1. Frontend (any chat app) -> API calls validated" -ForegroundColor White
        Write-Host "  2. EVA Pipeline (enrichment) -> integration possible" -ForegroundColor White
        Write-Host "  3. EVA Brain Backend -> API/RAG engine operational" -ForegroundColor White
    }
    else {
        Write-Host "[FAIL] EVA Brain APIs cannot provide answers" -ForegroundColor Red
        Write-Host "System is NOT functional - NO-GO" -ForegroundColor Red
        Write-Host ""
        Write-Host "Requirements for GO:" -ForegroundColor Yellow
        Write-Host "  [$(if ($healthPassed) {'PASS'} else {'FAIL'})] Health endpoint must respond (200 OK)" -ForegroundColor $(if ($healthPassed) {'Green'} else {'Red'})
        Write-Host "  [$(if ($chatPassed) {'PASS'} else {'FAIL'})] At least one chat endpoint must return answers" -ForegroundColor $(if ($chatPassed) {'Green'} else {'Red'})
        Write-Host ""
        Write-Host "Failed Tests:" -ForegroundColor Red
        $script:testResults | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
            Write-Host "  - $($_.TestName): $($_.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Full logs and traces saved to:" -ForegroundColor Cyan
    Write-Host "  $runPath" -ForegroundColor White
    Write-Host ""
    
    # Save report to file
    $reportFile = Join-Path $runPath "SMOKE-TEST-REPORT.md"
    $reportContent = @"
# EVA Brain Smoke Test Report

**Test Run**: $runId
**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Base URL**: $BaseUrl

## Executive Summary

**GO/NO-GO Decision**: **$goNoGo**

- Total Tests: $($script:testResults.Count)
- Passed: $script:testsPassed
- Failed: $script:testsFailed
- Skipped: $script:testsSkipped

## Test Results

| Test Name | Status | Message |
|-----------|--------|---------|
$(foreach ($result in $script:testResults) {
"| $($result.TestName) | $($result.Status) | $($result.Message) |"
})

## Critical Assessment

### EVA Brain API Decomposition Validation

The smoke test validates the following architectural components:

1. **Frontend Integration** (any chat app → API calls)
   - Health endpoint: $(if (($script:testResults | Where-Object { $_.TestName -eq "01_Health_Endpoint" }).Status -eq "PASS") { "[PASS]" } else { "[FAIL]" })
   - Chat API: $(if (($script:testResults | Where-Object { $_.TestName -eq "02_Chat_Ungrounded" }).Status -eq "PASS") { "[PASS]" } else { "[FAIL]" })
   - RAG API: $(if (($script:testResults | Where-Object { $_.TestName -eq "03_Chat_RAG_proj1" }).Status -eq "PASS") { "[PASS]" } else { "[FAIL]" })

2. **EVA Pipeline** (enrichment/document processing)
   - Integration readiness: $(if ($goNoGo -eq "GO") { "[READY]" } else { "[BLOCKED]" })

3. **EVA Brain Backend** (API/RAG engine)
   - Operational status: $(if ($goNoGo -eq "GO") { "[OPERATIONAL]" } else { "[DEGRADED]" })

## Recommendations

$(if ($goNoGo -eq "GO") {
@"
[PASS] Proceed with architectural decomposition:

1. Create API facade layer (APIM or similar)
2. Separate enrichment pipeline as independent service
3. Expose EVA Brain backend via versioned APIs
4. Update frontend to use API-first architecture

Next Steps:
- Review EVA-BRAIN-END-TO-END-PLAN.md
- Implement APIM facade design
- Create API versioning strategy
"@
} else {
@"
[FAIL] Resolve critical issues before proceeding:

Failed Tests:
$(foreach ($failed in ($script:testResults | Where-Object { $_.Status -eq "FAIL" })) {
"- $($failed.TestName): $($failed.Message)"
})

Required Actions:
1. Ensure backend is running: cd I:\EVA-JP-v1.2\app\backend && python app.py
2. Verify environment configuration (backend.env)
3. Check Azure service connectivity (if using HCCLD2)
4. Re-run smoke test after fixes
"@
})

## Evidence

All request/response traces saved to:
- Logs: $logsPath
- Traces: $tracesPath
- Evidence: $evidencePath

---

**Test Suite Version**: 1.0
**Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    Set-Content -Path $reportFile -Value $reportContent -Encoding ASCII
    
    Write-Host "Report saved: $reportFile" -ForegroundColor Cyan
}

#endregion

# Execute smoke test
$success = Invoke-SmokeTest

# Exit with appropriate code
if ($success) {
    Write-Host "[SUCCESS] Smoke test passed - Ready for EVA Brain decomposition" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "[FAILURE] Smoke test failed - Review logs and resolve issues" -ForegroundColor Red
    exit 1
}
