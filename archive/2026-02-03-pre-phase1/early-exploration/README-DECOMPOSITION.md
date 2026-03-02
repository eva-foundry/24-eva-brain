# EVA Brain - Architectural Decomposition PoC

> **Breaking the Monolith**: Transforming MS PubSec-Info-Assistant from monolithic to API-first microservices architecture

---

## The Real Vision

EVA Brain is **NOT** about GitHub Spark. It's about **decomposing the monolithic PubSec-Info-Assistant** into 3 decoupled, independently deployable services:

```
┌─────────────────────────────────────────────────────────────┐
│ MONOLITHIC (Current)                                         │
│ I:\PubSec-Info-Assistant → I:\EVA-JP-v1.2                   │
│                                                              │
│ [Frontend] ←→ [Backend] ←→ [Enrichment] (Tightly Coupled)   │
└─────────────────────────────────────────────────────────────┘

                           ↓ DECOMPOSE ↓

┌─────────────────────────────────────────────────────────────┐
│ MICROSERVICES (Target)                                       │
│                                                              │
│ ┌──────────────┐                                            │
│ │  Frontend    │ (Any chat app: React, Svelte, Mobile)      │
│ │  Layer       │ Communicates via REST APIs only            │
│ └──────┬───────┘                                            │
│        │ HTTP/JSON                                          │
│        ▼                                                     │
│ ┌──────────────────────────────────────────┐               │
│ │  EVA Brain Backend (API Layer)           │               │
│ │  - Chat API (/chat)                      │               │
│ │  - RAG API (/chat with selectedFolders)  │               │
│ │  - Sessions API (/sessions)              │               │
│ │  - Versioned endpoints (/v1/...)         │               │
│ └──────┬───────────────────────────────────┘               │
│        │ Queue/Events                                       │
│        ▼                                                     │
│ ┌──────────────────────────────────────────┐               │
│ │  EVA Pipeline (Enrichment Service)       │               │
│ │  - Document OCR (Form Recognizer)        │               │
│ │  - Chunking & Embeddings                 │               │
│ │  - Azure Search Indexing                 │               │
│ └──────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

---

## Why This Matters

### Current Problem (Monolithic)
- **Frontend tightly coupled** to backend Python/Quart code
- **Cannot reuse** EVA capabilities in other apps (mobile, Slack bot, Teams integration)
- **Scaling challenges**: Must scale entire monolith (frontend + backend + enrichment)
- **Deployment complexity**: Any change requires full system redeploy

### Solution (Microservices)
- **API-first architecture**: Any frontend can call EVA Brain APIs
- **Reusable intelligence**: EVA becomes a platform, not just an app
- **Independent scaling**: Scale chat separately from document processing
- **Flexible deployment**: Update enrichment pipeline without touching chat

---

## Phase 0: Smoke Test Validation

**Before** attempting decomposition, validate APIs work independently.

### Run Smoke Test

```powershell
# Ensure backend is running
cd I:\EVA-JP-v1.2\app\backend
python app.py  # Runs on localhost:5000

# In new terminal, run smoke test
cd I:\eva-foundation\24-eva-brain\scripts
.\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"
```

### What It Tests

| Test | Purpose | Validates |
|------|---------|-----------|
| **Health Endpoint** | Backend availability | Basic connectivity |
| **Chat Ungrounded** | Direct GPT-4 interaction | Chat API functional |
| **Chat RAG (proj1)** | Document Q&A with citations | RAG engine operational |
| **SSE Streaming** | Real-time responses | Streaming architecture |
| **Sessions API** | Conversation persistence | State management |

### GO/NO-GO Criteria

**GO** (Proceed with decomposition):
- ✅ Health check passes
- ✅ Chat ungrounded returns answer
- ✅ RAG query returns citations
- ✅ All API contracts validated

**NO-GO** (Fix issues first):
- ❌ Any critical test fails
- ❌ Backend not accessible
- ❌ RAG returns no citations

---

## Decomposition Roadmap

### Phase 1: API Contract Definition (Week 1)
- [x] Document existing endpoints (EVA-BRAIN-API-CONTRACTS.md)
- [x] Create smoke test suite
- [ ] Define versioned API schema (/v1/chat, /v1/sessions)
- [ ] Establish authentication strategy (Entra ID tokens)

### Phase 2: Frontend Decoupling (Week 2-3)
- [ ] Create API client library (TypeScript)
- [ ] Remove direct backend imports from frontend
- [ ] Configure frontend to use API base URL (environment variable)
- [ ] Test with existing EVA-JP backend (no changes)

### Phase 3: Backend API Layer (Week 4-5)
- [ ] Implement API facade (versioning, rate limiting)
- [ ] Add CORS configuration for multiple frontends
- [ ] Implement OpenAPI/Swagger documentation
- [ ] Deploy as standalone Azure Web App

### Phase 4: Enrichment Pipeline Separation (Week 6-7)
- [ ] Extract Azure Functions into separate deployment
- [ ] Create queue-based communication (backend → enrichment)
- [ ] Implement enrichment status API
- [ ] Deploy as standalone Function App

### Phase 5: APIM Integration (Week 8-9)
- [ ] Deploy Azure API Management
- [ ] Configure policies (auth, throttling, logging)
- [ ] Expose versioned APIs (/v1, /v2)
- [ ] Implement cost tracking headers

### Phase 6: Multi-Frontend Validation (Week 10)
- [ ] React frontend (existing EVA-JP)
- [ ] Svelte frontend (new PoC)
- [ ] Mobile-friendly SPA
- [ ] Postman/CLI client

---

## Project Structure

```
24-eva-brain/
├── README-DECOMPOSITION.md          # This file
├── FEASIBILITY-ASSESSMENT.md        # Risk analysis (GitHub Spark pivot)
├── ACTION-PLAN-REVISED.md           # Original Spark plan (deprecated)
├── EVA-BRAIN-API-CONTRACTS.md       # API specification (production-validated)
├── EVA-BRAIN-END-TO-END-PLAN.md     # APIM, telemetry, FinOps design
│
├── scripts/
│   └── EVA-Brain-Smoke-Test.ps1     # GO/NO-GO validation script ⭐
│
├── runs/
│   └── smoke-tests/                 # Test execution logs
│       └── smoke_test_YYYYMMDD_HHMMSS/
│           ├── logs/                # smoke_test.log
│           ├── traces/              # request/response dumps
│           ├── evidence/            # screenshots, artifacts
│           └── SMOKE-TEST-REPORT.md # GO/NO-GO decision report
│
└── api-contracts/                   # Future: OpenAPI specs, client SDKs
```

---

## Key Artifacts

### 1. EVA-Brain-Smoke-Test.ps1 ⭐ NEW
**Purpose**: Validate EVA Brain APIs work independently (Phase 0 validation)  
**Usage**: `.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"`  
**Output**: 
- Plain text logs (ASCII-safe)
- Request/response traces
- GO/NO-GO decision report

### 2. EVA-BRAIN-API-CONTRACTS.md
**Purpose**: Complete API specification for EVA-JP backend  
**Status**: ✅ Production-validated (Feb 2, 2026)  
**Contents**:
- Request/response formats
- Authentication (x-ms-client-principal-id)
- RAG parameters (selectedFolders)
- Environment configuration

### 3. EVA-BRAIN-END-TO-END-PLAN.md
**Purpose**: Comprehensive decomposition plan (APIM, telemetry, FinOps)  
**Scope**: 
- API facade design
- Cost tracking headers
- DevOps analytics integration
- Governance compliance (ITS07, IOP01)

---

## Quick Start

### 1. Validate APIs (Smoke Test)

```powershell
# Start backend
cd I:\EVA-JP-v1.2\app\backend
.\.venv\Scripts\Activate.ps1
python app.py

# Run smoke test (new terminal)
cd I:\eva-foundation\24-eva-brain\scripts
.\EVA-Brain-Smoke-Test.ps1

# Review results
code ..\runs\smoke-tests\smoke_test_*/SMOKE-TEST-REPORT.md
```

### 2. Review API Contracts

```powershell
code EVA-BRAIN-API-CONTRACTS.md
```

### 3. Plan Decomposition

```powershell
code EVA-BRAIN-END-TO-END-PLAN.md
```

---

## Success Criteria

### Phase 0 (Current)
- [x] API contracts documented
- [x] Smoke test suite created
- [ ] Smoke test passes with GO decision
- [ ] Evidence captured (logs, traces)

### Phase 1 (Decomposition Ready)
- [ ] Versioned API schema defined (/v1/...)
- [ ] Frontend uses API client only (no direct imports)
- [ ] Backend exposed via APIM
- [ ] Multiple frontends validated

### Phase 6 (Production)
- [ ] 3+ frontends using EVA Brain APIs
- [ ] Independent scaling proven
- [ ] Cost tracking operational
- [ ] Zero-downtime deployments

---

## Comparison: Original Plan vs. Reality

| Aspect | Original (Spark PoC) | Reality (Decomposition) |
|--------|---------------------|------------------------|
| **Purpose** | "Build chat UI with Spark" | Break monolith into microservices |
| **Timeline** | 1 week demo | 10 weeks phased rollout |
| **Deliverable** | React chat app | API-first architecture |
| **Success** | 10 developers see Spark | Multiple frontends use EVA APIs |
| **Value** | Learn Spark tool | Reusable AI platform |

---

## Related Documentation

- **[FEASIBILITY-ASSESSMENT.md](./FEASIBILITY-ASSESSMENT.md)** - GitHub Spark risk analysis (now deprecated context)
- **[EVA-BRAIN-API-CONTRACTS.md](./EVA-BRAIN-API-CONTRACTS.md)** - Complete API specification
- **[EVA-BRAIN-END-TO-END-PLAN.md](./EVA-BRAIN-END-TO-END-PLAN.md)** - APIM and telemetry design
- **[I:\EVA-JP-v1.2\.github\copilot-instructions.md](../../EVA-JP-v1.2/.github/copilot-instructions.md)** - EVA-JP architecture reference

---

## Support

**For Questions About**:

- **Smoke Test**: Run with `-Verbose` flag, review logs in `runs/smoke-tests/`
- **API Contracts**: See EVA-BRAIN-API-CONTRACTS.md, test with Postman
- **Decomposition Plan**: Review EVA-BRAIN-END-TO-END-PLAN.md
- **EVA-JP Backend**: See I:\EVA-JP-v1.2\.github\architecture-ai-context.md

---

**Last Updated**: February 3, 2026  
**Status**: Phase 0 - Smoke Test Implementation Complete ✅  
**Next Step**: Run smoke test and achieve GO decision 🚀

