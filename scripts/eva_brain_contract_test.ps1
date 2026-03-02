# EVA-FEATURE: F24-07
# EVA-STORY: F24-07-007
param(
    [Parameter(Mandatory=$true)][string]$BaseUrl,
    [string]$OutDir = "I:\\eva-foundation\\24-eva-brain\\runs\\contract-tests"
)

$ErrorActionPreference = "Stop"

New-Item -Force -ItemType Directory -Path $OutDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $OutDir "eva_brain_contract_test_$timestamp.md"

$ungrounded = @{
    history = @(@{ user = "Example question" })
    approach = 3
    overrides = @{
        byPassRAG = $true
        responseLength = 0
        responseTemp = 0
    }
    citation_lookup = @{}
    thought_chain = @{}
} | ConvertTo-Json -Depth 6

$rag = @{
    history = @(@{ user = "Example question" })
    approach = 1
    overrides = @{
        byPassRAG = $false
        selectedFolders = "proj1"
        selectedTags = ""
        top = 5
    }
    citation_lookup = @{}
    thought_chain = @{}
} | ConvertTo-Json -Depth 6

function Invoke-ChatCall {
    param(
        [string]$Name,
        [string]$Payload
    )

    $start = Get-Date
    try {
        $response = Invoke-RestMethod -Method Post -Uri "$BaseUrl/chat" -ContentType "application/json" -Body $Payload
        $status = "OK"
        $body = ($response | ConvertTo-Json -Depth 6)
    } catch {
        $status = "ERROR"
        $body = $_.Exception.Message
    }
    $end = Get-Date
    $duration = ($end - $start).TotalSeconds

    return @{
        Name = $Name
        Start = $start
        End = $end
        DurationSeconds = $duration
        Status = $status
        Body = $body
    }
}

$results = @()
$results += Invoke-ChatCall -Name "Ungrounded" -Payload $ungrounded
$results += Invoke-ChatCall -Name "RAG_Proj1" -Payload $rag

$lines = @()
$lines += "# EVA Brain Contract Test"
$lines += ""
$lines += "- Timestamp: $timestamp"
$lines += "- Base URL: $BaseUrl"
$lines += ""

foreach ($r in $results) {
    $lines += "## $($r.Name)"
    $lines += ""
    $lines += "- Start: $($r.Start.ToString('o'))"
    $lines += "- End: $($r.End.ToString('o'))"
    $lines += ("- Duration seconds: {0:N2}" -f $r.DurationSeconds)
    $lines += "- Status: $($r.Status)"
    $lines += ""
    $lines += "### Response"
    $lines += ""
    $lines += "````json"
    $lines += $r.Body
    $lines += "````"
    $lines += ""
}

$lines | Set-Content -Path $logPath

Write-Host "Wrote: $logPath"
