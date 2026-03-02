Write-Host "[INFO] Starting EVA Backend with marco-sandbox configuration" -ForegroundColor Cyan
Write-Host "[INFO] Service: marco-sandbox-openai-v2 (GPT-5.1)" -ForegroundColor Yellow
Write-Host "[INFO] Location: C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2\app\backend" -ForegroundColor Gray
Write-Host ""

Set-Location C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2\app\backend

Write-Host "[INFO] Starting Python app.py..." -ForegroundColor Yellow
Write-Host "[INFO] This will take 30-60 seconds for imports to load..." -ForegroundColor Gray
Write-Host "[INFO] Watch for 'INFO:     Uvicorn running on http://0.0.0.0:5000' message" -ForegroundColor Gray
Write-Host ""

python app.py
