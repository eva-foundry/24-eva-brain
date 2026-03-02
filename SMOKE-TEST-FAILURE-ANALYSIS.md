# EVA-JP-v1.2 Smoke Test Failure Analysis

**Date**: 2026-02-03 20:54:34  
**Test Run**: smoke_test_20260203_205434  
**Decision**: **NO-GO** ❌

## Executive Summary

Backend health endpoint responds (200 OK) but **all functional APIs return 500 Internal Server Error**. This indicates the server is running but crashes when attempting chat/RAG operations.

## Test Results

| Test | Status | Error |
|------|--------|-------|
| 01_Health_Endpoint | ✅ PASS | 200 OK |
| 02_Chat_Ungrounded | ❌ FAIL | 500 Internal Server Error |
| 03_Chat_RAG_proj1 | ❌ FAIL | 500 Internal Server Error |
| 04_Streaming_SSE | ❌ FAIL | 500 Internal Server Error |
| 05_Sessions_Create | ❌ FAIL | 405 Method Not Allowed |

**Pass Rate**: 20% (1/5 tests passed)

## Root Cause Hypothesis

### 1. Azure RBAC Permissions (Most Likely)

**Evidence from backend.env**:
```bash
# Comment in backend.env (lines 51-53):
# RBAC ISSUE: Need 'Cognitive Services OpenAI User' role on infoasst-aoai-dev2
# Current access: Reader only (insufficient for Azure OpenAI operations)
```

**Impact**: Backend cannot call Azure OpenAI API → 500 errors on all chat endpoints

**Fix Required**: Assign role in Azure Portal:
```powershell
az role assignment create `
    --role "Cognitive Services OpenAI User" `
    --assignee "marco.presta@hrsdc-rhdcc.gc.ca" `
    --scope "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/infoasst-dev2/providers/Microsoft.CognitiveServices/accounts/infoasst-aoai-dev2"
```

### 2. Missing Python Dependencies

**Symptom**: Backend starts but crashes on first API call  
**Possible causes**:
- `azure-identity` authentication failures
- `openai` SDK version mismatch
- `azure-search-documents` missing or incompatible

**Verification needed**:
```powershell
cd I:\EVA-JP-v1.2\app\backend
.\.venv\Scripts\python.exe -c "import openai; import azure.identity; import azure.search.documents; print('All imports OK')"
```

### 3. Configuration Issues (Already Fixed)

**Fixed**: Storage account mismatch
- ❌ **Before**: `marcosandboxstore20260203` (non-existent)
- ✅ **After**: `infoasststoredev2` (exists)

**Still in hybrid mode** (sandbox + dev2 mixed):
- Azure Search: `marco-sandbox-search` (sandbox)
- Cosmos DB: `marco-sandbox-cosmos` (sandbox, bypassed with `SKIP_COSMOS_DB=true`)
- Azure OpenAI: `infoasst-aoai-dev2` (dev2) ← **RBAC issue here**
- Storage: `infoasststoredev2` (dev2)
- Enrichment: `marco-sandbox-enrichment` (sandbox)

## Recommended Actions (Priority Order)

### Action 1: Fix Azure OpenAI RBAC (BLOCKING - HIGH PRIORITY)
1. Assign "Cognitive Services OpenAI User" role to marco.presta@hrsdc-rhdcc.gc.ca
2. Verify role assignment: `az role assignment list --assignee "marco.presta@hrsdc-rhdcc.gc.ca" --scope "/subscriptions/d2d4e571.../infoasst-aoai-dev2"`
3. Restart backend to pick up new permissions

### Action 2: Capture Backend Error Logs (DIAGNOSTIC)
1. Find backend console output (PowerShell window with backend running)
2. Capture stack trace from 500 error
3. Identify exact exception causing failure

### Action 3: Verify Python Dependencies (VALIDATION)
1. Test imports: `python -c "import openai; import azure.identity; print('OK')"`
2. If missing, install: `pip install -r requirements.txt`
3. Confirm Azure SDK versions match requirements.txt

### Action 4: Re-run Smoke Test (VERIFICATION)
After fixing RBAC:
```powershell
cd I:\eva-foundation\24-eva-brain\scripts
.\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"
```

**Expected outcome**: All 5 tests pass → GO decision

## Evidence Location

- **Smoke Test Results**: `I:\eva-foundation\24-eva-brain\runs\smoke-tests\smoke_test_20260203_205434\`
- **Backend Config**: `I:\EVA-JP-v1.2\app\backend\backend.env`
- **Test Logs**: `I:\eva-foundation\24-eva-brain\runs\smoke-tests\smoke_test_20260203_205434\smoke_test.log`
- **API Traces**: `*_request.txt` and `*_response.txt` files in test run directory

## GO Decision Criteria

For GO decision, ALL of the following must pass:
- ✅ Health endpoint responds (200 OK) - **ACHIEVED**
- ❌ Chat ungrounded returns answer - **BLOCKED**
- ❌ Chat RAG returns answer with citations - **BLOCKED**
- ❌ Streaming SSE delivers incremental responses - **BLOCKED**
- ✅ Sessions API creates/retrieves sessions - **OPTIONAL** (405 expected if endpoint not implemented)

**Current Status**: 1/4 mandatory tests passing (25%)

## Next Steps

1. **Immediate**: Assign Azure OpenAI RBAC role (5 minutes)
2. **Validation**: Restart backend, test single chat API call manually
3. **Verification**: Re-run full smoke test suite
4. **Documentation**: Update EVA Brain PROJECT-STATUS.md with findings

---

**Analysis by**: GitHub Copilot AI Assistant  
**Review needed**: Marco Presta
