# EVA Brain - Quick Start Guide

**Last Updated**: February 3, 2026  
**Purpose**: One-page guide to execute smoke test and make GO/NO-GO decision

---

## 30-Second Overview

**What is this?**: Architectural decomposition of Microsoft PubSec-Info-Assistant monolith into 3 microservices with universal API facade (EVA Face)

**Why EVA Face?**: Enable ANY client (1980s COBOL, browser extensions, modern webapps, CLI) to access AI intelligence without modernization

**Current Status**: Phase 0 documentation complete, ready for smoke test

**Next Action**: Execute smoke test → Review report → Make GO/NO-GO decision

---

## Quick Start (5 Minutes)

### Step 1: Start Backend (2 minutes)

```powershell
# Terminal 1: Start EVA-JP backend
cd I:\EVA-JP-v1.2\app\backend
.\.venv\Scripts\Activate.ps1
python app.py

# Wait for: "Running on http://localhost:5000"
```

### Step 2: Run Smoke Test (2 minutes)

```powershell
# Terminal 2: Run smoke test
cd I:\eva-foundation\24-eva-brain
.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"

# Watch for: Test progress, [PASS]/[FAIL] indicators
```

### Step 3: Review Report (1 minute)

```powershell
# Open report
cat runs\smoke-tests\smoke_test_*\SMOKE-TEST-REPORT.md

# Look for: "OVERALL DECISION: GO" or "OVERALL DECISION: NO-GO"
```

---

## Expected Output

### Success (GO)

```
[PASS] Test 1: Health Check
[PASS] Test 2: Chat Ungrounded
[PASS] Test 3: Chat RAG
[PASS] Test 4: Streaming Response
[PASS] Test 5: Sessions Endpoint

OVERALL DECISION: GO
Recommendation: Proceed to Phase 1 (EVA Face Gateway)
```

**Next Step**: Phase 1 - Build EVA Face gateway (Week 1-2)

---

### Failure (NO-GO)

```
[PASS] Test 1: Health Check
[FAIL] Test 2: Chat Ungrounded - Timeout
[FAIL] Test 3: Chat RAG - No citations
[PASS] Test 4: Streaming Response
[FAIL] Test 5: Sessions Endpoint - Connection error

OVERALL DECISION: NO-GO
Recommendation: Fix issues and re-test
```

**Troubleshooting**: See TROUBLESHOOTING section below

---

## Troubleshooting

### Backend Not Starting

**Symptom**: `python app.py` fails

**Solutions**:
1. Check Python version: `python --version` (need 3.10+)
2. Activate venv: `.\.venv\Scripts\Activate.ps1`
3. Install dependencies: `pip install -r requirements.txt`
4. Check environment file: `app\backend\backend.env` exists

---

### Smoke Test Fails - Health Check

**Symptom**: `[FAIL] Test 1: Health Check`

**Solutions**:
1. Verify backend running: `http://localhost:5000/health` in browser
2. Check port 5000 not in use: `netstat -ano | findstr :5000`
3. Try alternative port: `python app.py --port 5001`
4. Re-run smoke test: `.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5001"`

---

### Smoke Test Fails - Authentication

**Symptom**: `[FAIL] Test 2: Chat Ungrounded - 401 Unauthorized`

**Solutions**:
1. Check environment file: `I:\EVA-JP-v1.2\app\frontend\.env` exists
2. Verify auth headers present:
   ```
   REACT_APP_X_MS_CLIENT_PRINCIPAL_ID=fc1cf8cd-fce3-4ad5-bd16-58725f4e6a33
   REACT_APP_X_MS_CLIENT_PRINCIPAL_NAME=marco.presta@hrsdc-rhdcc.gc.ca
   ```
3. Disable auth in dev mode: `backend.env` set `DEV_MODE=true`

---

### Smoke Test Fails - RAG No Citations

**Symptom**: `[FAIL] Test 3: Chat RAG - No citations`

**Solutions**:
1. Check Azure Search index: `index-jurisprudence` has documents
2. Verify embeddings generated: Azure Search portal → Documents count > 0
3. Check search service connection: `backend.env` has correct `AZURE_SEARCH_ENDPOINT`
4. Test manually: Postman collection → "Chat - RAG (proj1)"

---

### Smoke Test Hangs

**Symptom**: Script stops responding

**Solutions**:
1. **Ctrl+C** to cancel
2. Check backend logs for errors
3. Increase timeout: Edit `EVA-Brain-Smoke-Test.ps1` line ~50 (`$timeout = 30` → `$timeout = 60`)
4. Run individual test: Comment out other tests in script

---

## Key Documents

**Strategic Vision**:
- [EVA-FACE-STRATEGY.md](./EVA-FACE-STRATEGY.md) - Complete 2-year roadmap (browser, legacy, governance)
- [PROJECT-STATUS-COMPLETE.md](./PROJECT-STATUS-COMPLETE.md) - Comprehensive status report

**Technical Docs**:
- [README.md](./README.md) - Main project documentation
- [README-DECOMPOSITION.md](./README-DECOMPOSITION.md) - Detailed decomposition plan
- [EVA-BRAIN-API-CONTRACTS.md](./EVA-BRAIN-API-CONTRACTS.md) - Production-validated API spec

**Quick Reference**:
- [QUICK-REFERENCE.md](./QUICK-REFERENCE.md) - One-page command reference

---

## Decision Matrix

| All Tests Pass? | Decision | Next Step |
|-----------------|----------|-----------|
| ✅ Yes (5/5) | **GO** | Phase 1: Build EVA Face Gateway (Week 1-2) |
| ⚠️ Partial (3-4/5) | **GO with caveats** | Fix non-critical issues in parallel with Phase 1 |
| ❌ No (<3/5) | **NO-GO** | Fix issues, re-test, reassess |

---

## Phase Roadmap

### Phase 0: Smoke Test (This Week) ⭐ CURRENT
- **Goal**: GO/NO-GO decision
- **Deliverable**: Smoke test report
- **Exit**: GO decision → Phase 1

### Phase 1: EVA Face Gateway (Week 1-2)
- **Goal**: Thin API facade
- **Deliverable**: EVA Face working, smoke test passes against it
- **Exit**: <5ms latency overhead, 100% API compatibility

### Phase 2: Multi-Client (Week 3-4)
- **Goal**: 3 diverse clients
- **Deliverable**: Browser extension, COBOL integration, PowerShell CLI
- **Exit**: 50+ users adopt browser, 1 dept COBOL, 20+ CLI

### Phase 3: Governance (Week 5-6)
- **Goal**: AI governance at edge
- **Deliverable**: Content safety, rate limiting, cost tracking, audit logs
- **Exit**: IT-SG333 compliance passed

### Phase 4: Production (Week 7-10)
- **Goal**: 1000+ users
- **Deliverable**: Load tested, multi-region, disaster recovery
- **Exit**: 99.9% uptime, <2s p95 latency, $5k/month cost

---

## FAQ

**Q: What is EVA Face?**  
A: Universal API gateway enabling ANY client (legacy, browser, modern) to access EVA Brain intelligence

**Q: Why not just use EVA Brain directly?**  
A: EVA Face adds governance (content safety, rate limiting, audit logs) and deployment flexibility

**Q: What's the difference between EVA Face and EVA Brain?**  
A: EVA Face = thin gateway (auth, logging, governance). EVA Brain = intelligence (GPT-4, RAG, search)

**Q: Can legacy COBOL really call AI?**  
A: Yes! EVA Face provides REST API accessible via JCL HTTPREQ program (no COBOL changes)

**Q: What if smoke test fails?**  
A: See TROUBLESHOOTING section. Most issues are env config (auth headers, Azure Search index)

**Q: How long to production?**  
A: 10 weeks (Phase 0 → Phase 4). Phase 0 (smoke test) takes 1 day.

**Q: What's the cost?**  
A: $900/month for EVA Face + $4k/month existing EVA Brain = $5k/month total

---

## Support

**Project Owner**: Marco Presta  
**Email**: marco.presta@hrsdc-rhdcc.gc.ca  
**Repository**: I:\eva-foundation\24-eva-brain

**For Help**:
- Smoke test issues: See TROUBLESHOOTING above
- Strategic questions: Read EVA-FACE-STRATEGY.md
- Technical details: Read architecture-ai-context.md (EVA-JP-v1.2 repo)

---

**Last Updated**: February 3, 2026  
**Status**: Phase 0 Complete - Ready for Smoke Test ✅  
**Next Command**: `.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"` 🚀
