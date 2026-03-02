# EVA Brain - Universal AI Intelligence Platform

> **Strategic Vision**: Break the monolith → Deploy AI anywhere → Democratize intelligence across the organization  
> **EVA Face**: API facade enabling 1980s legacy systems to modern browsers to leverage GPT-4 RAG capabilities

---

## 🎯 The Complete Vision

**EVA Brain** = Backend intelligence (GPT-4 RAG engine)  
**EVA Face** = Universal API facade (deploy anywhere - browser extensions, legacy COBOL, modern webapps)  
**EVA Pipeline** = Document enrichment (OCR, embeddings, indexing)

**Strategic Goal**: AICOE maintains intelligence layer, organization deploys EVA Face anywhere, governance enforced at the edge.

---

## Table of Contents

- [Strategic Overview](#strategic-overview)
- [Architecture](#architecture)
- [Quick Start - Smoke Test](#quick-start---smoke-test)
- [Project Structure](#project-structure)
- [Key Artifacts](#key-artifacts)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Deployment](#deployment)
- [Related Projects](#related-projects)

---

## Strategic Overview

### Purpose

EVA Brain is the **architectural decomposition** of Microsoft's PubSec-Info-Assistant monolith into 3 independently deployable microservices:

1. **EVA Brain Backend** (Intelligence Layer) - GPT-4o RAG engine, maintained by AICOE
2. **EVA Face** (Universal Facade) - API gateway deployable anywhere (browser, legacy, modern apps)
3. **EVA Pipeline** (Enrichment Service) - Document processing (OCR, embeddings, indexing)

**Timeline**: Phase 0 validation -- 24-week phased rollout  
**Target**: Organization-wide AI democratization (1000+ users, 20+ applications)  
**Status**: PROJECT CLOSED - Feb 25, 2026 12:42 PM ET -- Successor: 33-eva-brain-v2 (active)

### Strategic Value

- **Democratize AI**: Any system (1980s COBOL to modern React) calls EVA Face → gets GPT-4 intelligence
- **AICOE Focus**: Maintain intelligence layer (EVA Brain), outsource integration (EVA Face deployment to business units)
- **Governance at Edge**: IT-SG333, AI governance, content safety enforced at EVA Face gateway
- **Legacy Modernization**: 1980s/2000s systems get AI without rewrite (REST API integration)
- **Scale Without Growth**: 1000+ users leverage centralized intelligence via distributed facades

---

## Architecture

### Current State: Monolithic

```
┌─────────────────────────────────────────────────────────────┐
│ MS PubSec-Info-Assistant (Monolith)                          │
│ I:\PubSec-Info-Assistant → I:\EVA-JP-v1.2                   │
│                                                              │
│ [React Frontend] ←→ [Quart Backend] ←→ [Functions Pipeline] │
│ (Tightly coupled - cannot deploy independently)              │
└─────────────────────────────────────────────────────────────┘
```

### Target State: Microservices with EVA Face

```
┌─────────────────────────────────────────────────────────────┐
│                   UNIVERSAL CLIENTS                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Browser    │  │   Legacy     │  │   Modern     │     │
│  │  Extension   │  │ 1980s COBOL  │  │  React App   │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         └──────────────────┼──────────────────┘             │
│                            ▼                                 │
│         ┌──────────────────────────────────┐                │
│         │      EVA FACE (API Facade)       │                │
│         │  • APIM Gateway                  │                │
│         │  • Entra ID Auth                 │                │
│         │  • AI Governance                 │                │
│         │  • IT-SG333 Compliance           │                │
│         └──────────────┬───────────────────┘                │
│                        ▼                                     │
│         ┌──────────────────────────────────┐                │
│         │    EVA BRAIN (Intelligence)      │                │
│         │  • Chat API (/chat)              │                │
│         │  • RAG API (docs + citations)    │                │
│         │  • GPT-4o + Azure Search         │                │
│         └──────────────┬───────────────────┘                │
│                        ▼                                     │
│         ┌──────────────────────────────────┐                │
│         │  EVA PIPELINE (Enrichment)       │                │
│         │  • OCR (Form Recognizer)         │                │
│         │  • Embeddings (text-ada-002)     │                │
│         │  • Indexing (Cognitive Search)   │                │
│         └──────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### EVA-JP Backend Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend** | React 18 + TypeScript + Vite | SPA with streaming chat |
| **Backend** | Python Quart (async Flask) | RESTful API + SSE streaming |
| **AI/ML** | Azure OpenAI (gpt-4o) | Chat completions + embeddings |
| **Search** | Azure Cognitive Search | Hybrid vector + keyword search |
| **Storage** | Azure Blob Storage | Document storage (`proj1-upload`) |
| **Database** | Azure Cosmos DB | Session logs, user context |
| **Auth** | Entra ID (App Service Easy Auth) | SSO with `x-ms-client-principal-id` |
| **Network** | HCCLD2 VNet (private endpoints) | Secure mode deployment |

---

## Quick Start

### Prerequisites

- **GitHub Copilot Pro+** subscription ($39/month) for Spark access
- **Access to EVA-JP backend** (VPN or Microsoft DevBox for HCCLD2)
- **Git** for repository operations
- **Node.js 18+** and **Python 3.10+** for local testing

### 1. Review Documentation

```powershell
# Clone repository
git clone <eva-suite-repo>
cd eva-foundation/24-eva-brain

# Read key documents
code README.md                                    # This file
code EVA-BRAIN-API-CONTRACTS.md                   # API specification
code ../../EVA-JP-v1.2/docs/prd-eva-chat-spark-poc.md  # Product requirements
```

### 2. Validate API Contracts

```powershell
# Test EVA-JP backend connectivity
.\scripts\eva_brain_contract_test.ps1 -BaseUrl "https://domain.eva.service.gc.ca"

# Review results
code runs/contract-tests/eva_brain_contract_test_*.md
```

### 3. Start Spark Development

1. Open [GitHub Spark](https://github.com/spark)
2. Create new application
3. Paste PRD + API Contract as context
4. Describe chat interface: "Build a clean chat interface with Chat and RAG modes that calls POST /chat endpoint..."
5. Iterate with natural language commands
6. Export code when satisfied
 

“A fully functional React chat UI generated in Spark, exportable without Spark runtime dependencies, and deployable to Azure App Service.”



### 4. Merge to EVA Brain

```powershell
# Create feature branch
git checkout -b spark-poc-chat-ui

# Copy exported Spark code
cp -r ~/Downloads/spark-export/* app/

# Test locally
cd app
npm install
npm run dev  # Frontend at localhost:5173

# Test backend integration
# (Backend should already be running at localhost:5000)

# Commit and push
git add .
git commit -m "Add Spark-generated chat UI with RAG support"
git push origin spark-poc-chat-ui
```

---

## Project Structure

```
24-eva-brain/
├── README.md                          # This file (project overview)
├── README-DECOMPOSITION.md            # Detailed decomposition plan
├── EVA-FACE-STRATEGY.md              # ⭐ Strategic vision document
├── QUICK-REFERENCE.md                 # Quick commands & troubleshooting
├── FEASIBILITY-ASSESSMENT.md          # Risk analysis (archived)
├── ACTION-PLAN-REVISED.md             # Original Spark plan (deprecated)
│
├── EVA-BRAIN-API-CONTRACTS.md         # API specification (production-validated)
├── EVA-BRAIN-END-TO-END-PLAN.md       # APIM, telemetry, FinOps design
├── COPILOT-DISCOVERY-RUNBOOK.md       # Browser-based API discovery guide
│
├── scripts/
│   └── EVA-Brain-Smoke-Test.ps1       # ⭐ GO/NO-GO validation script
│
├── postman/
│   └── EVA-BRAIN.postman_collection.json  # Postman collection for testing
│
├── configs/                           # Configuration templates
├── evidence/                          # Captured API responses, screenshots
├── inputs/                            # Test data, sample questions
└── runs/
    └── smoke-tests/                   # ⭐ Smoke test execution logs
        └── smoke_test_YYYYMMDD_HHMMSS/
            ├── logs/                  # Full execution log
            ├── traces/                # Request/response dumps
            ├── evidence/              # Screenshots, artifacts
            └── SMOKE-TEST-REPORT.md   # GO/NO-GO decision
```

---

## Key Artifacts

### 1. EVA-JP-v1.2-ARCHITECTURE.md ⭐ NEW

**Purpose**: Complete architectural reference for EVA Jurisprudence v1.2 monolith  
**Status**: ✅ Comprehensive documentation (Feb 7, 2026)  
**Contents**:
- Full frontend architecture (React + TypeScript + Vite)
- Backend architecture (FastAPI + Python)
- 25+ React components breakdown
- 17+ API endpoints specification
- Sandbox deployment configuration (marco-sandbox-*)
- RBAC system design
- RAG approach implementations
- Decomposition recommendations for EVA Brain

**Use Case**: Baseline reference for EVA Brain decomposition, understanding current monolith

### 2. EVA-FACE-STRATEGY.md ⭐

**Purpose**: Complete strategic vision for organization-wide AI democratization  
**Status**: ✅ Strategic roadmap defined (Feb 3, 2026)  
**Contents**:
- EVA Face deployment patterns (browser, legacy, modern)
- Governance framework integration (AI governance, IT-SG333, FinOps)
- 2-year roadmap (1000+ users, 20+ applications)
- Code samples (COBOL, TypeScript, PowerShell)
- Long-term vision (agentic, autonomous, cross-government)

**Use Case**: Strategic planning, executive presentations, architecture decisions

### 3. EVA-Brain-Smoke-Test.ps1 ⭐

**Purpose**: GO/NO-GO validation script for EVA Face architecture  
**Status**: ✅ Complete and tested (Feb 3, 2026)  
**Usage**: `.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"`  
**Output**:
- Plain text logs (ASCII-safe)
- Request/response traces
- GO/NO-GO decision report

**Use Case**: Phase 0 validation before decomposition work begins

### 4. EVA-BRAIN-API-CONTRACTS.md

**Purpose**: Complete API specification for EVA-JP backend  
**Status**: ✅ Production-validated (Feb 2, 2026)  
**Contents**:
- Request/response formats for `/chat` endpoint
- Production-captured examples (PSHCP eligibility query)
- Streaming response patterns (SSE token-by-token)
- Authentication details (x-ms-client-principal-id header)
- RAG structure (data_points, citation_lookup, thought_chain)
- Environment configuration (Azure resources)
- System comparison (OpenWebUI vs EVA-JP)

**Use Case**: Primary reference for Spark development

### 5. prd-eva-chat-spark-poc.md

**Location**: `I:\EVA-JP-v1.2\docs\prd-eva-chat-spark-poc.md`  
**Purpose**: Product Requirements Document for Spark PoC  
**Status**: ✅ Complete  
**Contents**:
- Product overview and strategic goals
- 3 personas (Developer, Architect, End User)
- 5 functional requirements
- UX narrative and success metrics
- 3-phase timeline (1 week total)
- 10 testable user stories

**Use Case**: Context for Spark when building UI

### 6. COPILOT-DISCOVERY-RUNBOOK.md

**Purpose**: Guide for manual API discovery using browser DevTools  
**Status**: ✅ Validated (used to capture production examples)  
**Contents**:
- Step-by-step browser-based discovery process
- Network capture instructions (HAR export)
- Safety and governance notes (ITS07, IOP01 compliance)
- Output format specification

**Use Case**: Fallback method if automated testing fails

### 7. eva_brain_contract_test.ps1

**Purpose**: Automated API contract validation  
**Status**: ✅ Working (tested Feb 2, 2026)  
**Usage**:
```powershell
.\scripts\eva_brain_contract_test.ps1 -BaseUrl "https://domain.eva.service.gc.ca"
```
**Output**: Markdown report in `runs/contract-tests/`

**Use Case**: Validate API availability before Spark development

### 5. EVA-BRAIN.postman_collection.json

**Purpose**: Postman collection for API testing  
**Status**: ✅ Complete  
**Includes**:
- Chat (Ungrounded) request
- Chat (RAG - proj1) request
- Variable templates for base_url

**Use Case**: Manual API testing, contract validation

---

## Development Workflow

### Phase 0: Smoke Test Validation [COMPLETE - Feb 12, 2026]

**Purpose**: Validate API decomposition feasibility with GO/NO-GO decision

**Steps**:
1. Start EVA-JP backend locally:
   ```powershell
   cd I:\EVA-JP-v1.2\app\backend
   python app.py  # Runs on localhost:5000
   ```

2. Run smoke test:
   ```powershell
   cd I:\eva-foundation\24-eva-brain
   .\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"
   ```

3. Review GO/NO-GO decision:
   ```powershell
   # Report location: runs/smoke-tests/smoke_test_*/SMOKE-TEST-REPORT.md
   cat runs\smoke-tests\smoke_test_*\SMOKE-TEST-REPORT.md
   ```

**Success Criteria**:
- ✅ Health check passes
- ✅ Chat returns answer
- ✅ RAG returns citations
- ✅ Streaming works
- ✅ Sessions persist

**Exit Condition**: GO decision → proceed to Phase 1

---

### Phase 1: EVA Face API Gateway (Week 1-2)

**Purpose**: Create thin API facade layer that wraps EVA Brain

**Deliverables**:
1. Reverse proxy with:
   - `/health` → EVA Brain health check
   - `/chat` → EVA Brain chat endpoint
   - `/sessions` → EVA Brain sessions endpoint
2. Basic authentication passthrough
3. Logging and telemetry hooks
4. OpenAPI specification

**Technology**: 
- Python (Flask/FastAPI/Quart) for consistency with EVA Brain
- Docker container deployment
- Azure API Management integration hooks

**Success Criteria**:
- EVA Face calls work identically to direct EVA Brain calls
- Smoke test passes against EVA Face instead of EVA Brain
- <5ms latency overhead

---

### Phase 2: EVA Face Clients (Week 3-4)

**Purpose**: Demonstrate EVA Face deployment flexibility

**Client 1: Browser Extension** (TypeScript)
```typescript
// Content script injects AI assistant into any webpage
const response = await fetch('https://eva-face.gc.ca/chat', {
  method: 'POST',
  headers: {'x-ms-client-principal-id': userId},
  body: JSON.stringify({question: selectedText})
});
```

**Client 2: Legacy COBOL Integration** (JCL + REST)
```cobol
CALL 'HTTPREQ' USING EVA-FACE-URL, REQUEST-BODY, RESPONSE-BODY
DISPLAY "AI Response: " RESPONSE-BODY
```

**Client 3: PowerShell CLI** (Windows automation)
```powershell
Ask-EVABrain "What are PSHCP mental health coverage limits?"
```

**Success Criteria**:
- 3 diverse client types working
- Same answers from all clients
- <500 lines of code per client

---

### Phase 3: Governance Integration (Week 5-6)

**Purpose**: Add AI governance controls at EVA Face layer

**Features**:
1. Content safety filtering (Azure Content Safety)
2. Rate limiting per user/department
3. Cost tracking and budget alerts (FinOps)
4. Audit logging (all requests/responses)
5. IT-SG333 compliance reporting

**Integration Points**:
- Azure Monitor Application Insights
- Cosmos DB audit logs
- Azure Cost Management alerts
- ESDC compliance dashboards

**Success Criteria**:
- Blocked inappropriate query
- Rate limit enforced (user gets 429)
- Cost alert triggered at $100/month
- Audit report generated

---

### Phase 4: Scale & Optimize (Week 7-10)

**Purpose**: Production-ready deployment

**Activities**:
1. Load testing (100 concurrent users)
2. Private endpoint configuration (HCCLD2 VNet)
3. Multi-region deployment (Canada East + Central)
4. Disaster recovery testing
5. Performance optimization (<2s p95 latency)
6. Documentation and training

**Deployment Targets**:
- EVA Face: Azure App Service (Standard tier)
- EVA Brain: Existing infrastructure (no changes)
- EVA Pipeline: Existing infrastructure (no changes)

**Success Criteria**:
- 100 concurrent users with <2s latency
- 99.9% uptime over 7 days
- Zero data leakage between departments
- Complete deployment runbook

---

## Testing

## Testing

### Smoke Test (Phase 0 Validation)

**Purpose**: GO/NO-GO decision for API decomposition

**Prerequisites**:
1. EVA-JP backend running on localhost:5000
2. Valid authentication headers in `I:\EVA-JP-v1.2\app\frontend\.env`

**Execution**:
```powershell
cd I:\eva-foundation\24-eva-brain
.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"
```

**Output Structure**:
```
runs/smoke-tests/smoke_test_YYYYMMDD_HHMMSS/
├── logs/smoke_test.log                # Full execution log
├── traces/
│   ├── health_request.json           # /health request/response
│   ├── chat_ungrounded_*.json        # Chat request/response
│   ├── chat_rag_*.json               # RAG request/response
│   ├── streaming_*.json              # SSE streaming test
│   └── sessions_*.json               # Sessions CRUD test
├── evidence/
│   └── [Any captured artifacts]
└── SMOKE-TEST-REPORT.md               # ⭐ GO/NO-GO decision
```

**GO Criteria** (ALL must pass):
- ✅ Health check returns 200 OK
- ✅ Chat returns answer (>50 characters)
- ✅ RAG returns citations (data_points array present)
- ✅ Streaming works (SSE chunks received)
- ✅ Sessions persist (GET returns saved session)

**NO-GO Scenarios**:
- ❌ Health check fails (backend not running)
- ❌ Authentication fails (invalid headers)
- ❌ RAG returns empty citations (search index issue)
- ❌ Streaming hangs (SSE connection timeout)
- ❌ Sessions not persisting (Cosmos DB issue)

---

### Contract Testing (Production Validation)

**Purpose**: Validate EVA Face against production APIs

**Test EVA-JP Backend** (localhost):
```powershell
# Start backend
cd I:\EVA-JP-v1.2\app\backend
python app.py

# Run smoke test
cd I:\eva-foundation\24-eva-brain
.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"
```

**Test Production EVA-JP** (Azure):
```powershell
# Requires VPN + Entra ID authentication
.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "https://your-instance.azurewebsites.net"

# Expected: Redirect to Entra ID login
# After auth: Full smoke test execution
```

**Test EVA Face Gateway** (after Phase 1):
```powershell
# Test EVA Face instead of EVA Brain directly
.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "https://eva-face.gc.ca"

# Should produce IDENTICAL results to direct EVA Brain calls
```

---

### Integration Testing (Phase 2+)

**Browser Extension Test**:
1. Install extension locally (`chrome://extensions`)
2. Navigate to any webpage with text
3. Select text → Right-click → "Ask EVA Brain"
4. Verify: AI answer appears in side panel
5. Verify: Citations link back to source documents

**Legacy COBOL Test**:
1. Deploy JCL job with EVA Face API call
2. Submit job to z/OS mainframe
3. Verify: Job completes successfully (RC=0)
4. Verify: SYSOUT contains AI-generated answer
5. Verify: Audit log captured request

**PowerShell CLI Test**:
```powershell
# Install module
Import-Module .\modules\EVABrain.psm1

# Test ungrounded chat
Ask-EVABrain "What is employment insurance?"

# Test RAG mode
Ask-EVABrain "PSHCP mental health coverage" -UseRAG -Folder "proj1"

# Verify: Answer with citations returned
```

---

### Load Testing (Phase 4)

**Purpose**: Validate production scalability

**Tools**: Apache JMeter or Azure Load Testing

**Scenario 1: Concurrent Users**
- 100 simultaneous chat requests
- Expected: <2s p95 latency, 0% errors

**Scenario 2: Sustained Load**
- 10 requests/second for 1 hour
- Expected: <3s p95 latency, <1% errors

**Scenario 3: Spike Test**
- 0 → 500 users in 10 seconds
- Expected: Graceful degradation, no crashes

**Success Criteria**:
- 99.9% success rate
- <2s p95 latency under load
- <5s p99 latency under load
- No memory leaks over 1 hour
- Auto-scaling triggers at 70% CPU

---
cd I:\eva-foundation\24-eva-brain
.\scripts\eva_brain_contract_test.ps1 -BaseUrl "http://localhost:5000"
```

### Manual Testing with Postman

```powershell
# Import collection
# File: I:\eva-foundation\24-eva-brain\postman\EVA-BRAIN.postman_collection.json

# Set environment variable
base_url = http://localhost:5000  # Or production URL

# Run requests:
# - Chat - Ungrounded
# - Chat - RAG (proj1)
```

### Browser-Based Testing

Follow [COPILOT-DISCOVERY-RUNBOOK.md](./COPILOT-DISCOVERY-RUNBOOK.md):
1. Open browser with DevTools (F12)
2. Navigate to https://domain.eva.service.gc.ca/
3. Authenticate with marco.presta@hrsdc-rhdcc.gc.ca
4. Capture network traffic for chat requests
5. Validate response format matches contract

---

## Deployment

### Phase 0: Local Development (Current)

**EVA Brain Backend** (EVA-JP):
```powershell
cd I:\EVA-JP-v1.2\app\backend
.\.venv\Scripts\Activate.ps1
python app.py
# Runs on http://localhost:5000
```

**EVA Brain Frontend** (EVA-JP):
```powershell
cd I:\EVA-JP-v1.2\app\frontend
npm install
npm run dev
# Runs on http://localhost:5173
```

**Smoke Test Validation**:
```powershell
cd I:\eva-foundation\24-eva-brain
.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "http://localhost:5000"
# Output: runs/smoke-tests/smoke_test_*/SMOKE-TEST-REPORT.md
```

---

### Phase 1: EVA Face Gateway (Week 1-2)

**Container Build**:
```dockerfile
# Dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

**Azure Container Apps Deployment**:
```powershell
# Create container registry
az acr create --resource-group rg-eva --name acrevaface --sku Basic

# Build and push image
az acr build --registry acrevaface --image eva-face:v1 .

# Deploy to Container Apps
az containerapp create \
  --name eva-face \
  --resource-group rg-eva \
  --image acrevaface.azurecr.io/eva-face:v1 \
  --target-port 8000 \
  --ingress external \
  --env-vars EVA_BRAIN_URL=https://eva-brain-internal.azurewebsites.net
```

**Verification**:
```powershell
# Test EVA Face instead of EVA Brain directly
.\scripts\EVA-Brain-Smoke-Test.ps1 -BaseUrl "https://eva-face.gc.ca"
# Should produce identical results to direct EVA Brain calls
```

---

### Phase 2: Multi-Client Deployment (Week 3-4)

**Browser Extension** (Chrome/Edge):
1. Package extension: `npm run build:extension`
2. Load unpacked extension in Chrome
3. Deploy to Chrome Web Store (internal only)

**Legacy COBOL Integration** (JCL):
```jcl
//EVAFACE  JOB  (ACCT),'EVA FACE CALL',CLASS=A,MSGCLASS=X
//STEP1    EXEC PGM=HTTPREQ
//SYSOUT   DD   SYSOUT=*
//SYSIN    DD   *
URL=https://eva-face.gc.ca/chat
METHOD=POST
BODY={"question":"What is EI misconduct?"}
/*
```

**PowerShell Module** (Windows):
```powershell
# Install from corporate repository
Install-Module -Name EVABrain -Repository CorpNuGet

# Or local installation
Import-Module .\modules\EVABrain.psm1

# Usage
Ask-EVABrain "PSHCP eligibility"
```

---

### Phase 3: Production (Week 7-10)

**Azure App Service** (EVA Brain - no changes):
```powershell
cd I:\EVA-JP-v1.2
make build-deploy-webapp  # Existing deployment process
```

**Azure API Management** (EVA Face):
```powershell
# Create APIM instance
az apim create --name apim-eva-face --resource-group rg-eva --publisher-email admin@gc.ca

# Import OpenAPI spec
az apim api import --api-id eva-face --path /api --specification-format OpenApiJson --specification-url https://eva-face.gc.ca/openapi.json

# Configure policies (rate limiting, logging)
az apim api policy create --api-id eva-face --xml-policy policies/api-policy.xml
```

**Private Endpoint Configuration** (HCCLD2 VNet):
```powershell
# Create private endpoint for EVA Brain
az network private-endpoint create \
  --resource-group rg-eva \
  --name pe-eva-brain \
  --vnet-name hccld2-vnet \
  --subnet private-endpoints \
  --private-connection-resource-id /subscriptions/.../resourceGroups/rg-eva/providers/Microsoft.Web/sites/eva-brain

# EVA Face remains public-facing with authentication
```

---

## Documentation References

### Strategic Vision

- **[EVA-FACE-STRATEGY.md](./EVA-FACE-STRATEGY.md)** ⭐ - Complete strategic roadmap (browser, legacy, governance, 2-year plan)
- **[README-DECOMPOSITION.md](./README-DECOMPOSITION.md)** - Detailed architectural decomposition (3 microservices, 6 phases)
- **[QUICK-REFERENCE.md](./QUICK-REFERENCE.md)** - One-page command reference (smoke test, troubleshooting)

### API Contracts & Testing

- **[EVA-BRAIN-API-CONTRACTS.md](./EVA-BRAIN-API-CONTRACTS.md)** - Complete API specification (production-validated Feb 2, 2026)
- **[EVA-BRAIN-END-TO-END-PLAN.md](./EVA-BRAIN-END-TO-END-PLAN.md)** - APIM, telemetry, FinOps implementation plan
- **[COPILOT-DISCOVERY-RUNBOOK.md](./COPILOT-DISCOVERY-RUNBOOK.md)** - Manual API discovery guide (browser DevTools)

### EVA-JP Documentation

- **[copilot-instructions.md](../../EVA-JP-v1.2/.github/copilot-instructions.md)** - Quick reference workflows, conventions
- **[architecture-ai-context.md](../../EVA-JP-v1.2/.github/architecture-ai-context.md)** - Comprehensive architecture reference (AI-optimized)
- **[PYTHON-SETUP-QUICK-START.md](../../EVA-JP-v1.2/PYTHON-SETUP-QUICK-START.md)** - Python environment setup (offline packages)

### Foundation Best Practices

- **[best-practices-reference.md](../07-foundation-layer/02-design/best-practices-reference.md)** - Universal coding patterns
- **[marco-framework-architecture.md](../07-foundation-layer/02-design/marco-framework-architecture.md)** - Professional components (DebugArtifactCollector, SessionManager, StructuredErrorHandler)

---

## Related Projects

### EVA-JP-v1.2 (Production Monolith)

**Location**: `I:\EVA-JP-v1.2`  
**Purpose**: Production RAG system for jurisprudence Q&A  
**Status**: Production (HCCLD2 deployment)  
**Relevance**: **EVA Brain** in 3-service architecture

**Key Components**:
- Backend: `app/backend/app.py` (Quart API, GPT-4o, Azure Search)
- Frontend: `app/frontend/src/` (React/TypeScript)
- Pipeline: `functions/` (Azure Functions - OCR, embeddings, indexing)

**Decomposition Role**:
- EVA Brain = Backend API (`/chat`, `/sessions`, `/health`)
- EVA Pipeline = Functions (OCR, chunking, embedding)
- EVA Face = NEW thin gateway (to be created)

---

### PubSec-Info-Assistant (Microsoft Base)

**Location**: `I:\PubSec-Info-Assistant`  
**Purpose**: Original Microsoft monolith template  
**Status**: Reference only  
**Relevance**: Source architecture EVA-JP is based on

**Usage**: Historical context, not active development

---

### Project 02: PoC Agent Skills

**Location**: `I:\eva-foundation\02-poc-agent-skills`  
**Purpose**: Core agent skills library  
**Status**: Active development  
**Relevance**: "Contract-first development" pattern (mock testing before execution)

**Key Pattern**: Validate external dependency contracts before execution to fail fast

---

### Project 14: Azure FinOps

**Location**: `I:\eva-foundation\14-az-finops`  
**Purpose**: Cost management automation (Azure Cost Management, Data Factory)  
**Status**: Active (offline package management solution)  
**Relevance**: EVA Face cost tracking integration (Phase 3)

**Key Pattern**: Offline Python package download for ESDC internal pip repository

---

### Open-WebUI (Reference Architecture)

**Location**: `I:\open-webui`  
**Purpose**: Reference architecture for modern AI chat UI  
**Status**: Analysis only  
**Relevance**: UI/UX patterns (originally for Spark PoC, now deprecated)

---

## Governance & Compliance

## Governance & Compliance

### ESDC Requirements Traceability

| Requirement | Source | Implementation | Status |
|-------------|--------|----------------|--------|
| **ITS07** | No external API exposure | EVA Face provides controlled access layer with APIM | Phase 1 |
| **IOP01** | Restrict integrations | Integration limited to authenticated clients via Entra ID | Phase 1 |
| **INF01** | Access expectations | Role-based access (SHOW_STRICTBOX, CPPD_GROUPS) | ✅ Existing |
| **IT-SG333** | Security controls | EVA Face enforces audit logging, rate limiting | Phase 3 |

### AI Governance Integration

**Phase 3 Deliverables** (Week 5-6):
- Content safety filtering (Azure Content Safety at EVA Face layer)
- Responsible AI reporting (usage patterns, bias detection)
- Cost tracking and budget alerts (Azure Cost Management)
- User consent and transparency (AIDA compliance)

**Audit Trails**:
- All requests/responses logged to Cosmos DB
- PII detection and masking
- Retention policy (7 years per ESDC standards)
- Export capability for investigations

### Security Controls

**Authentication** (Phase 1):
- Entra ID OAuth 2.0 at EVA Face layer
- x-ms-client-principal-id header validation
- JWT token verification

**Authorization** (Phase 2):
- RBAC groups control folder access
- Rate limiting per user/department (1000 requests/day)
- IP allowlisting for legacy systems (COBOL mainframe)

**Network Security** (Phase 4):
- EVA Brain behind private endpoint (HCCLD2 VNet)
- EVA Face public-facing with WAF (Azure Front Door)
- TLS 1.3 encryption for all traffic

**Data Protection**:
- No PII in logs (automatic masking)
- Document encryption at rest (Azure Storage SSE)
- Deletion workflows (GDPR compliance)

---

## Success Metrics

### Phase 0: Smoke Test (Current)

**Goal**: GO/NO-GO decision for decomposition feasibility

**Metrics**:
- ✅ All 5 API tests pass (health, chat, RAG, streaming, sessions)
- ✅ Latency <2s for RAG queries
- ✅ Citations returned for document queries

**Exit Condition**: GO decision enables Phase 1 funding approval

---

### Phase 1: EVA Face Gateway (Week 1-2)

**Goal**: Thin API facade working identically to EVA Brain

**Metrics**:
- Smoke test passes against EVA Face (not EVA Brain)
- <5ms latency overhead vs. direct EVA Brain calls
- 100% API compatibility (no client changes required)

**Success**: 10 AICOE developers successfully call EVA Face APIs

---

### Phase 2: Multi-Client Adoption (Week 3-4)

**Goal**: 3 diverse client types deployed

**Metrics**:
- Browser extension installed by 50+ users
- Legacy COBOL system successfully integrated (1 department)
- PowerShell CLI adopted by 20+ administrators

**Success**: Same answers from all clients (consistency validated)

---

### Phase 3: Governance at Scale (Week 5-6)

**Goal**: AI governance enforced at EVA Face edge

**Metrics**:
- Content safety blocks 100% of inappropriate queries (0 false negatives)
- Rate limiting enforces budget ($100/month per department)
- Audit logs capture 100% of requests (0 gaps)

**Success**: IT-SG333 compliance audit passed

---

### Phase 4: Production (Week 7-10)

**Goal**: 1000+ users across ESDC

**Metrics**:
- 99.9% uptime over 30 days
- <2s p95 latency under 100 concurrent users
- $5,000/month total cost (within budget)
- 20+ applications integrated (browser, legacy, modern)

**Success**: Zero data leakage incidents, zero unplanned outages

---

## Support & Contact

### EVA Face Project

**Project Owner**: Marco Presto  
**Email**: marco.presta@hrsdc-rhdcc.gc.ca  
**Repository**: I:\eva-foundation\24-eva-brain

**For Questions About**:
- Smoke test execution and results
- EVA Face architecture and design
- Integration patterns (browser, COBOL, CLI)
- Governance and compliance requirements

---

### EVA Brain Backend (EVA-JP)

**Project Team**: AICOE Dev Team  
**Repository**: I:\EVA-JP-v1.2  
**Documentation**: `.github/architecture-ai-context.md`

**For Questions About**:
- Backend API implementation (Quart, Azure OpenAI)
- Document pipeline (OCR, embeddings, indexing)
- Azure infrastructure (App Service, Search, Cosmos DB)
- Production deployment and operations

---

### Related Services

**Azure API Management**: AICOE Platform Team  
**Azure Cost Management**: Project 14 (I:\eva-foundation\14-az-finops)  
**AI Governance**: ESDC AI Governance Office  
**Security Controls**: IT Security (IT-SG333 compliance)

---

## Changelog

### 2026-02-25 - PROJECT CLOSED - 12:42 PM ET

**Decision**: Project retired. Active development continues in 33-eva-brain-v2.
- Phase 0 (smoke test validation) complete -- GO decision confirmed Feb 12, 2026
- All architectural learnings transferred to 33-eva-brain-v2
- 33-eva-brain-v2 Sprint 5 complete: 577/577 tests, 72% coverage, 60/60 endpoints
- This repo preserved as read-only reference

**Successor**: C:\AICOE\eva-foundation\33-eva-brain-v2

---

### 2026-02-03 - Strategic Vision Complete [ARCHIVED]

**EVA Face Strategy**:
- ✅ Created EVA-FACE-STRATEGY.md (400+ lines, strategic 2-year roadmap)
- ✅ Defined deployment patterns (browser extension, COBOL legacy, modern webapp, CLI)
- ✅ Integrated governance framework (AI governance, IT-SG333, FinOps)
- ✅ Established success metrics (technical, business, governance)
- ✅ Updated README.md with complete decomposition vision

**Key Documents Created**:
- EVA-FACE-STRATEGY.md - Strategic vision and roadmap
- README-DECOMPOSITION.md - Architectural decomposition plan (3 microservices, 6 phases)
- QUICK-REFERENCE.md - One-page command reference
- scripts/EVA-Brain-Smoke-Test.ps1 - GO/NO-GO validation script (450 lines)

**Status**: Phase 0 complete - smoke test ready for execution

---

### 2026-02-02 - Phase 0 API Validation Complete ✅

**API Discovery & Contracts**:
- ✅ Created comprehensive API contracts with production validation
- ✅ Captured real EVA-JP traffic (PSHCP query with citations)
- ✅ Validated streaming response patterns (SSE token-by-token)
- ✅ Documented authentication flow (x-ms-client-principal-id header)
- ✅ Distinguished Current EVA Chat (OpenWebUI) from Target EVA-JP
- ✅ Created test harness (eva_brain_contract_test.ps1)

**Initial Misconception Resolved**:
- Original assumption: GitHub Spark PoC for UI development
- Actual purpose: Architectural decomposition (monolith → 3 microservices)
- Pivot: Focus shifted from Spark to EVA Face gateway pattern

**Status**: Ready for smoke test execution (Phase 0 → Phase 1 decision gate)

---

### Next Milestones

**Phase 0: Smoke Test** (This week):
- Run EVA-Brain-Smoke-Test.ps1 against localhost:5000
- Review SMOKE-TEST-REPORT.md for GO/NO-GO decision
- **Exit Condition**: GO decision → Proceed to Phase 1

**Phase 1: EVA Face Gateway** (Week 1-2):
- Build thin API facade (Python/Quart)
- Deploy to Azure Container Apps
- Validate with smoke test (should pass identically)
- **Exit Condition**: Smoke test passes against EVA Face

**Phase 2: Multi-Client Deployment** (Week 3-4):
- Browser extension (Chrome/Edge)
- Legacy COBOL integration (JCL)
- PowerShell CLI module
- **Exit Condition**: 3 client types working, same answers

---

**Last Updated**: February 25, 2026  
**Status**: PROJECT CLOSED - Feb 25, 2026 12:42 PM ET  
**Successor**: 33-eva-brain-v2 (active -- Sprint 5 complete, 577/577 tests, 72% coverage)
