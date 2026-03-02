# EVA Brain - Quick Reference Card

**Project Type**: Architectural Decomposition (Monolith → Microservices)  
**Status**: Phase 0 - Smoke Test Validation  
**Date**: February 3, 2026

---

## The Vision (One-Liner)

**Break MS PubSec-Info-Assistant monolith into 3 independent services: Frontend (any app) → EVA Brain Backend (APIs) → EVA Pipeline (enrichment)**

---

## Quick Commands

### Run Smoke Test (Phase 0 Validation)

```powershell
# 1. Start backend (terminal 1)
cd I:\EVA-JP-v1.2\app\backend
python app.py

# 2. Run smoke test (terminal 2)
cd I:\eva-foundation\24-eva-brain\scripts
.\EVA-Brain-Smoke-Test.ps1

# 3. Review results
code ..\runs\smoke-tests\smoke_test_*\SMOKE-TEST-REPORT.md
```

### Test Production Backend

```powershell
.\EVA-Brain-Smoke-Test.ps1 -BaseUrl "https://infoasst-web-hccld2.azurewebsites.net"
```

---

## What Gets Tested

| Test | API | Purpose |
|------|-----|---------|
| 1. Health | `GET /health` | Backend alive |
| 2. Chat Ungrounded | `POST /chat` | GPT-4 direct |
| 3. Chat RAG | `POST /chat` (proj1) | Document Q&A |
| 4. Streaming | `POST /chat` (stream=true) | SSE validation |
| 5. Sessions | `POST /sessions` | State management |

---

## GO/NO-GO Decision

**GO Criteria** (All must pass):
- ✅ Health returns 200
- ✅ Chat returns answer
- ✅ RAG returns citations

**NO-GO Triggers**:
- ❌ Backend not accessible
- ❌ Chat fails
- ❌ RAG has no citations

---

## Output Structure

```
runs/smoke-tests/smoke_test_YYYYMMDD_HHMMSS/
├── logs/
│   └── smoke_test.log              # Full execution log
├── traces/
│   ├── 01_Health_Endpoint_request.txt
│   ├── 01_Health_Endpoint_response.txt
│   ├── 02_Chat_Ungrounded_request.txt
│   ├── 02_Chat_Ungrounded_response.txt
│   ├── 03_Chat_RAG_proj1_request.txt
│   ├── 03_Chat_RAG_proj1_response.txt
│   └── ...
├── evidence/                       # Future: screenshots, artifacts
└── SMOKE-TEST-REPORT.md            # GO/NO-GO decision summary
```

---

## Three Services Architecture

### 1. Frontend Layer (Decoupled)
- **Technology**: React, Svelte, Mobile, CLI, Teams bot
- **Communication**: REST APIs only (no direct backend imports)
- **Configuration**: `VITE_API_BASE_URL=http://localhost:5000`

### 2. EVA Brain Backend (API Layer)
- **Location**: `I:\EVA-JP-v1.2\app\backend`
- **Endpoints**: `/health`, `/chat`, `/sessions`, `/files`
- **Future**: `/v1/chat`, `/v1/sessions` (versioned APIs)

### 3. EVA Pipeline (Enrichment)
- **Location**: `I:\EVA-JP-v1.2\functions`
- **Purpose**: OCR, chunking, embeddings, indexing
- **Communication**: Queue-based (decoupled from backend)

---

## Key Files

| File | Purpose | Status |
|------|---------|--------|
| `scripts/EVA-Brain-Smoke-Test.ps1` | GO/NO-GO validation | ✅ Complete |
| `README-DECOMPOSITION.md` | Architectural vision | ✅ Complete |
| `EVA-BRAIN-API-CONTRACTS.md` | API specification | ✅ Validated |
| `EVA-BRAIN-END-TO-END-PLAN.md` | APIM/telemetry design | ✅ Complete |
| `FEASIBILITY-ASSESSMENT.md` | Risk analysis (Spark pivot) | 📄 Deprecated context |

---

## Typical Test Run Output

```
============================================
  EVA Brain API Smoke Test
  Validating API Decomposition Concept
============================================

Base URL: http://localhost:5000
Output: ../runs/smoke-tests/smoke_test_20260203_140530
Run ID: smoke_test_20260203_140530

[2026-02-03 14:05:32] [INFO] Running Test: 01_Health_Endpoint
[2026-02-03 14:05:33] [PASS] Health endpoint returned 200 OK

[2026-02-03 14:05:34] [INFO] Running Test: 02_Chat_Ungrounded
[2026-02-03 14:05:38] [PASS] Chat ungrounded returned answer: Employment Insurance (EI) is a Canadian government program...

[2026-02-03 14:05:40] [INFO] Running Test: 03_Chat_RAG_proj1
[2026-02-03 14:05:55] [PASS] RAG query returned answer with 5 citations

============================================
  Test Results Summary
============================================

Total Tests: 5
Passed: 5
Failed: 0
Skipped: 0

============================================
  GO/NO-GO DECISION: GO
============================================

[PASS] EVA Brain APIs are functional
Ready to proceed with architectural decomposition:
  1. Frontend (any chat app) -> API calls validated
  2. EVA Pipeline (enrichment) -> integration possible
  3. EVA Brain Backend -> API/RAG engine operational
```

---

## Troubleshooting

### Backend Not Running
```
[FAIL] Health check failed - cannot proceed with API tests
[CRITICAL] Backend not accessible at http://localhost:5000
```
**Solution**: `cd I:\EVA-JP-v1.2\app\backend && python app.py`

### Authentication Errors
**Symptom**: 401 Unauthorized  
**Solution**: Script uses dev auth headers from `I:\EVA-JP-v1.2\app\frontend\.env`
```powershell
# Verify headers in script match .env
X_MS_CLIENT_PRINCIPAL_ID="fc1cf8cd-fce3-4ad5-bd16-58725f4e6a33"
```

### RAG Returns No Citations
**Symptom**: Answer without `data_points`  
**Possible Causes**:
- Azure Search index empty
- Enrichment pipeline not processed documents
- `selectedFolders` parameter missing

**Solution**: Check Azure Search index has documents in `proj1` folder

---

## Next Steps After GO Decision

1. **Define Versioned APIs** - `/v1/chat`, `/v1/sessions`
2. **Create API Client Library** - TypeScript SDK for frontends
3. **Implement APIM Facade** - Azure API Management configuration
4. **Separate Enrichment Service** - Deploy Functions independently
5. **Multi-Frontend Validation** - React + Svelte + Mobile clients

---

## Related Commands

```powershell
# Test with verbose logging
.\EVA-Brain-Smoke-Test.ps1 -Verbose

# Test production backend (requires VPN)
.\EVA-Brain-Smoke-Test.ps1 -BaseUrl "https://infoasst-web-hccld2.azurewebsites.net"

# Custom output directory
.\EVA-Brain-Smoke-Test.ps1 -OutputDir "C:\temp\eva-tests"

# View latest test results
code ..\runs\smoke-tests\(Get-ChildItem ..\runs\smoke-tests | Sort-Object Name -Descending | Select-Object -First 1).FullName\SMOKE-TEST-REPORT.md
```

---

## Success Metrics

### Phase 0 (Current)
- [ ] Smoke test returns GO decision
- [ ] All 5 API tests pass
- [ ] Request/response traces captured
- [ ] Evidence saved to `runs/smoke-tests/`

### Phase 1 (API Contracts)
- [ ] OpenAPI spec created
- [ ] Versioned endpoints defined (/v1/...)
- [ ] Authentication strategy documented
- [ ] Rate limiting designed

### Phase 6 (Production)
- [ ] 3+ frontends using EVA APIs
- [ ] APIM deployed with policies
- [ ] Independent scaling validated
- [ ] Cost tracking operational

---

**For Full Documentation**: See [README-DECOMPOSITION.md](./README-DECOMPOSITION.md)  
**For API Specification**: See [EVA-BRAIN-API-CONTRACTS.md](./EVA-BRAIN-API-CONTRACTS.md)  
**For APIM Design**: See [EVA-BRAIN-END-TO-END-PLAN.md](./EVA-BRAIN-END-TO-END-PLAN.md)

