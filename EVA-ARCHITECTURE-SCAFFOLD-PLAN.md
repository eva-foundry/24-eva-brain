# EVA Architecture Scaffold Plan - Complete Vision

**Date**: February 3, 2026  
**Purpose**: Comprehensive scaffold aligning EVA Face strategy with actual Azure infrastructure  
**Subscriptions**: EsDAICoESub (Dev/Stage), EsPAICoESub (Production)  
**Evidence Source**: `I:\eva-foundation\system-analysis\inventory\.eva-cache`

---

## EXECUTIVE SUMMARY

**Two Distinct EVA Systems Discovered**:

1. **EVA Chat** (OpenWebUI-based) - General-purpose conversational AI
2. **EVA Domain Assistant** (Microsoft Info Assistant) - Document-focused RAG system for jurisprudence

**Strategic Vision**: EVA Face = Universal API gateway enabling both systems to be consumed by ANY client (browser extensions, COBOL legacy, modern webapps, CLI tools) without client awareness of backend complexity.

**Current State**: Both systems deployed in EsDAICoESub (HCCLD2), production instances expected in EsPAICoESub.

---

## PART 1: DISCOVERED AZURE INFRASTRUCTURE

### EsDAICoESub Subscription (d2d4e571-e0f2-4f6c-901a-f88f7669bcba)

**Purpose**: Development and Staging environments  
**Region**: Canada Central (primary), Canada East (Azure OpenAI)  
**Network**: HCCLD2 VNet (private endpoints, secure-by-default)

---

### SYSTEM 1: EVA Chat (OpenWebUI)

**Resource Groups**:
- `EVAChatDevRg` - Development environment
- `EVAChatStgRg` - Staging environment

**Identified Resources** (from evidence cache):

| Resource Name | Type | Location | Purpose | Security |
|---------------|------|----------|---------|----------|
| **evachatstgsa** | Storage Account | canadacentral | Document uploads, user data | 🔒 Private |
| **evachatdev3sa** | Storage Account | canadacentral | Dev environment storage | 🔒 Private |
| **evachatstg2sa** | Storage Account | canadacentral | Staging storage (v2) | 🔒 Private |
| **evachat-poc-redis** | Redis Cache | canadacentral | Session caching, rate limiting | 🔒 Private endpoint |

**Expected Components** (OpenWebUI architecture):
- Backend: Python/FastAPI or Svelte 5
- Frontend: Svelte/TypeScript SPA
- Database: PostgreSQL or SQLite
- Vector Store: ChromaDB or Qdrant (embedded)
- Model Access: Azure OpenAI (shared or dedicated)

**Characteristics**:
- General-purpose chat interface
- Multi-model support (GPT-4, GPT-3.5)
- User conversation history
- Simple document Q&A
- Plugin/pipeline architecture

**Status**: Deployed in Dev/Stage, awaiting production inventory

---

### SYSTEM 2: EVA Domain Assistant (Microsoft Info Assistant)

**Architecture Pattern**: PubSec-Info-Assistant (Microsoft template)  
**Purpose**: Secure jurisprudence document Q&A with RAG

#### Resource Groups in EsDAICoESub:

**Development Environments**:
- `infoasst-dev0` - Dev environment #0
- `infoasst-dev1` - Dev environment #1
- `infoasst-dev2` - Dev environment #2 ⭐ **COMPLETE ARCHITECTURE DOCUMENTED**
- `infoasst-dev3` - Dev environment #3
- `infoasst-hccld2` - HCCLD2 secure environment

**Staging Environments**:
- `infoasst-stg1` - Staging environment #1
- `infoasst-stg2` - Staging environment #2
- `infoasst-stg3` - Staging environment #3

**Test Environments**:
- `infoasst-test-hrgqu` - Test environment

#### Complete Architecture (infoasst-dev2 Reference)

**Total Resources**: 63 components

**Core Intelligence Services**:

| Service | Resource Name | Type | Region | Purpose |
|---------|---------------|------|--------|---------|
| **Azure OpenAI** | infoasst-aoai-dev2 | Cognitive Services | Canada East | GPT-4o chat + embeddings |
| **Cognitive Search** | infoasst-search-dev2 | Search Service | Canada Central | Hybrid vector+keyword search |
| **Cosmos DB** | infoasst-cosmos-dev2 | GlobalDocumentDB | Canada Central | Session logs, audit trails |
| **Blob Storage** | infoasststoredev2 | Storage Account V2 | Canada Central | Document storage |
| **Document Intelligence** | infoasst-docint-dev2 | FormRecognizer | Canada Central | OCR processing |
| **AI Services** | infoasst-aisvc-dev2 | Cognitive Services | Canada Central | Query optimization, content safety |

**Application Tier**:

| Service | Resource Name | Type | Purpose |
|---------|---------------|------|---------|
| **Backend API** | infoasst-web-dev2 | App Service (Linux) | Python/Quart API (/chat, /upload, /sessions) |
| **Enrichment Service** | infoasst-enrichmentweb-dev2 | App Service (Linux) | Flask embedding service |
| **Function App** | infoasst-func-dev2 | Function App (Python) | Document pipeline (OCR, chunking, indexing) |

**Network & Security**:
- VNet: `infoasst-vnet-dev2`
- **20+ Private Endpoints** (all services behind firewall)
- Security Level: **Maximum** (all public access disabled, Azure AD only)

**Azure OpenAI Deployments** (infoasst-aoai-dev2):
1. **gpt-4o** (2024-08-06) - 60 TPM capacity
2. **dev2-text-embedding** (text-embedding-3-small v1) - 30 TPM capacity

**Status**: Fully operational across dev0-dev3, stg1-stg3, hccld2

---

### SHARED AZURE OPENAI SERVICES (EsDAICoESub)

**Foundational Services** (shared across projects):

| Service | Subscription | Location | Deployments | Status | Notes |
|---------|--------------|----------|-------------|--------|-------|
| **EsDAICoE-AI-Foundry-OpenAI** | EsDAICoESub | Canada East | gpt-4o-chat | ⚠️ 403 Forbidden | Private endpoint issue |
| **EsDAICoE-OpenAI-Stg** | EsDAICoESub | Canada East | gpt-4o | ❌ No access | RBAC permissions required |
| **eqvis-poc-ai-services** | EsDAICoESub | Canada East | gpt-4o | ✅ Functional | Public access enabled (test only) |
| **EsDAICoE-AI-Services** | EsDAICoESub | Canada East | Multi-service | ✅ Functional | Shared AI services |
| **test1234433** | EsDAICoESub | Canada Central | AI Services | ✅ Functional | Test environment |

**Access Patterns**:
- ✅ **eqvis-poc-ai-services**: Public access (functional test passed)
- ⚠️ **Private endpoint services**: Require HCCLD2 VNet access or DevBox
- ❌ **RBAC-restricted**: Require elevated permissions (listKeys action)
- ✅ **disableLocalAuth=true**: Best practice (API keys disabled, Azure AD only)

---

## PART 2: EVA FACE ARCHITECTURE DESIGN

### Strategic Vision: Universal API Gateway Pattern

```
┌────────────────────────────────────────────────────────────────┐
│                     ANY CLIENT TYPE                             │
│  (Browser Extension | COBOL | Modern Webapp | PowerShell CLI)   │
└────────────────┬───────────────────────────────────────────────┘
                 │
                 ↓
┌────────────────────────────────────────────────────────────────┐
│                      EVA FACE (API Gateway)                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Routing Logic:                                          │  │
│  │  - /chat → Route to EVA Chat OR EVA Domain Assistant    │  │
│  │  - /upload → Route to EVA Domain Assistant              │  │
│  │  - /sessions → Unified session management               │  │
│  │  - /health → Aggregate health check                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Authentication: Entra ID (x-ms-client-principal-id)            │
│  Authorization: RBAC groups (folder-level access)               │
│  Governance: Content safety, rate limiting, cost tracking       │
│  Audit: All requests/responses logged to Cosmos DB              │
└────────┬────────────────────────────┬────────────────────────────┘
         │                            │
         ↓                            ↓
┌────────────────────────┐  ┌────────────────────────────────────┐
│   EVA CHAT             │  │   EVA DOMAIN ASSISTANT             │
│   (OpenWebUI)          │  │   (MS Info Assistant)              │
│                        │  │                                    │
│  - General chat        │  │  - Document Q&A                    │
│  - Multi-model         │  │  - Jurisprudence RAG               │
│  - Simple RAG          │  │  - Hybrid search                   │
│  - Plugins             │  │  - OCR pipeline                    │
│                        │  │  - Citation tracking               │
└────────────────────────┘  └────────────────────────────────────┘
```

### Routing Strategy

**Intelligent Backend Selection**:

| Request Pattern | Route To | Reason |
|----------------|----------|---------|
| `/chat` + no `selectedFolders` | **EVA Chat** | General conversational AI |
| `/chat` + `selectedFolders` present | **EVA Domain Assistant** | Document-specific RAG |
| `/chat` + `useRAG=false` | **EVA Chat** | Direct GPT-4 access |
| `/upload` | **EVA Domain Assistant** | Document processing pipeline |
| `/sessions` + context="jurisprudence" | **EVA Domain Assistant** | Domain-specific history |
| `/sessions` + context="general" | **EVA Chat** | General chat history |

**Fallback Logic**:
1. If EVA Domain Assistant unavailable → Route to EVA Chat (degraded mode, no RAG)
2. If EVA Chat unavailable → Direct Azure OpenAI (no context, stateless)
3. If both unavailable → Return 503 with retry-after header

---

## PART 3: PHASE-BY-PHASE IMPLEMENTATION PLAN

### Phase 0: Infrastructure Discovery & Validation (Week 0) ✅ COMPLETE

**Completed**:
- ✅ Analyzed `.eva-cache` evidence (45 Azure resources inventoried)
- ✅ Identified two distinct systems (EVA Chat, EVA Domain Assistant)
- ✅ Mapped complete architecture (infoasst-dev2 reference: 63 resources)
- ✅ Validated Azure OpenAI functional access (eqvis-poc-ai-services working)
- ✅ Documented network security patterns (HCCLD2 private endpoints)

**Deliverables**:
- This document (EVA-ARCHITECTURE-SCAFFOLD-PLAN.md)
- Evidence summaries from `.eva-cache`
- Resource inventory JSON files

**Next Action**: Get EsPAICoESub production inventory to confirm live services

---

### Phase 1: EVA Face Gateway - Routing Layer (Week 1-2)

**Goal**: Build thin API gateway that routes to EVA Chat OR EVA Domain Assistant

**Architecture**:
```python
# EVA Face Gateway (Python/Quart)
from quart import Quart, request, jsonify
import httpx

app = Quart(__name__)

# Backend endpoints
EVA_CHAT_URL = "https://evachat-stg.azurewebsites.net"
EVA_DOMAIN_URL = "https://infoasst-web-dev2.azurewebsites.net"

@app.route("/chat", methods=["POST"])
async def route_chat():
    """Intelligent routing based on request context"""
    data = await request.json()
    
    # Route to EVA Domain Assistant if document-specific
    if data.get("selectedFolders") or data.get("context") == "jurisprudence":
        backend = EVA_DOMAIN_URL
    else:
        backend = EVA_CHAT_URL
    
    # Proxy request with authentication passthrough
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{backend}/chat",
            json=data,
            headers={"x-ms-client-principal-id": request.headers.get("x-ms-client-principal-id")}
        )
    
    return response.json(), response.status_code
```

**Deliverables**:
1. EVA Face codebase (Python/Quart, 500 lines)
2. Dockerfile + Azure Container Apps deployment
3. OpenAPI specification (3.0)
4. Routing decision logic (documented)
5. Smoke test passing against EVA Face

**Success Criteria**:
- Smoke test passes identically against EVA Face vs. direct backends
- <10ms latency overhead (routing decision only)
- 100% API compatibility (no client changes required)
- Graceful fallback if one backend unavailable

**Deployment**:
- Azure Container Apps (Consumption tier, $50/month)
- Region: Canada Central
- Ingress: External, HTTPS only
- Environment variables: `EVA_CHAT_URL`, `EVA_DOMAIN_URL`, `AZURE_CLIENT_ID`

---

### Phase 2: Multi-Client Deployment (Week 3-4)

**Goal**: Demonstrate EVA Face flexibility with 3 diverse clients

#### Client 1: Browser Extension (Chrome/Edge)

**Technology**: TypeScript, Chrome Extension Manifest V3

**Features**:
- Right-click context menu: "Ask EVA Brain"
- Side panel for AI responses
- Automatic context detection (general vs. jurisprudence)
- Citation rendering for domain-specific queries

**Code Sample**:
```typescript
// content-script.ts
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "askEVA") {
    fetch('https://eva-face.gc.ca/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-ms-client-principal-id': getUserId() // From Chrome identity
      },
      body: JSON.stringify({
        question: request.selectedText,
        context: detectContext(window.location.href) // "general" or "jurisprudence"
      })
    })
    .then(res => res.json())
    .then(data => {
      sendResponse({answer: data.answer, citations: data.citations});
    });
  }
  return true; // Async response
});
```

**Deployment**: Chrome Web Store (internal only, 50+ user target)

---

#### Client 2: Legacy COBOL Integration (JCL)

**Technology**: z/OS JCL with HTTPREQ program

**Code Sample**:
```jcl
//EVAFACE  JOB  (ACCT),'EVA FACE CALL',CLASS=A,MSGCLASS=X
//STEP1    EXEC PGM=HTTPREQ
//SYSOUT   DD   SYSOUT=*
//INPUT    DD   *
{"question":"What are EI misconduct rules?","context":"jurisprudence"}
/*
//CONFIG   DD   *
URL=https://eva-face.gc.ca/chat
METHOD=POST
HEADER=Content-Type:application/json
HEADER=x-ms-client-principal-id:COBOL-SYSTEM-001
/*
```

**Integration**: Submit JCL job → EVA Face processes → AI response in SYSOUT → Parse and use in COBOL program

**Deployment**: One pilot department (1 COBOL system)

---

#### Client 3: PowerShell CLI Module

**Technology**: PowerShell module (PSM1)

**Code Sample**:
```powershell
# EVABrain.psm1
function Ask-EVABrain {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Question,
        
        [switch]$UseRAG,
        
        [string]$Folder
    )
    
    $body = @{
        question = $Question
        context = if ($UseRAG) { "jurisprudence" } else { "general" }
    }
    
    if ($Folder) {
        $body.selectedFolders = @($Folder)
    }
    
    $response = Invoke-RestMethod `
        -Uri "https://eva-face.gc.ca/chat" `
        -Method POST `
        -Headers @{"x-ms-client-principal-id" = $env:USER_PRINCIPAL_ID} `
        -Body ($body | ConvertTo-Json) `
        -ContentType "application/json"
    
    return $response.answer
}

# Usage:
# Ask-EVABrain "What is EI misconduct?"
# Ask-EVABrain "PSHCP eligibility" -UseRAG -Folder "proj1"
```

**Deployment**: Corporate NuGet repository (20+ admin target)

---

**Phase 2 Success Criteria**:
- 3 client types working identically
- Browser extension: 50+ installs
- COBOL integration: 1 department pilot
- PowerShell CLI: 20+ users
- Same answers from all clients (consistency validated)
- <500 lines of code per client

---

### Phase 3: Governance Integration (Week 5-6)

**Goal**: Add AI governance controls at EVA Face layer

#### Governance Components

**1. Content Safety (Azure Content Safety)**

```python
# EVA Face - Content safety middleware
from azure.ai.contentsafety import ContentSafetyClient

async def check_content_safety(text: str) -> bool:
    """Block inappropriate content before routing"""
    client = ContentSafetyClient(endpoint=CONTENT_SAFETY_ENDPOINT)
    
    response = await client.analyze_text(text)
    
    # Block if hate speech, violence, or sexual content detected
    if any(category.severity > 2 for category in response.categories):
        return False
    
    return True

@app.route("/chat", methods=["POST"])
async def route_chat():
    data = await request.json()
    
    # Content safety check
    if not await check_content_safety(data.get("question")):
        return jsonify({"error": "Content policy violation"}), 400
    
    # ... routing logic
```

**2. Rate Limiting (APIM Policies)**

```xml
<!-- Azure API Management Policy -->
<policies>
    <inbound>
        <!-- Rate limit: 1000 requests/day per user -->
        <rate-limit-by-key calls="1000" renewal-period="86400" 
                           counter-key="@(context.Request.Headers.GetValueOrDefault('x-ms-client-principal-id'))" />
        
        <!-- Cost tracking -->
        <log-to-eventhub logger-id="cost-tracking">
            @{
                return new {
                    user = context.Request.Headers.GetValueOrDefault("x-ms-client-principal-id"),
                    timestamp = DateTime.UtcNow,
                    endpoint = context.Request.Url.Path,
                    estimatedCost = 0.01 // $0.01 per request
                };
            }
        </log-to-eventhub>
    </inbound>
</policies>
```

**3. Audit Logging (Cosmos DB)**

```python
# EVA Face - Audit logging
from azure.cosmos import CosmosClient

async def log_request(user_id: str, request_data: dict, response_data: dict):
    """Log all requests/responses for audit"""
    cosmos_client = CosmosClient(COSMOS_ENDPOINT)
    container = cosmos_client.get_database_client("audit").get_container_client("requests")
    
    await container.create_item({
        "id": str(uuid.uuid4()),
        "timestamp": datetime.utcnow().isoformat(),
        "user_id": user_id,
        "request": request_data,
        "response": {
            "status": response_data.get("status"),
            "answer_length": len(response_data.get("answer", "")),
            "citations_count": len(response_data.get("citations", []))
        },
        "ttl": 220752000  # 7 years (ESDC retention policy)
    })
```

**4. Cost Tracking (Azure Cost Management)**

```powershell
# Cost alert automation
$budget = @{
    name = "EVA-Face-Budget"
    amount = 100  # $100/month per department
    timeGrain = "Monthly"
    category = "Cost"
    notifications = @{
        "80PercentThreshold" = @{
            enabled = $true
            operator = "GreaterThan"
            threshold = 80
            contactEmails = @("manager@gc.ca")
        }
        "100PercentThreshold" = @{
            enabled = $true
            operator = "GreaterThan"
            threshold = 100
            contactEmails = @("manager@gc.ca", "finance@gc.ca")
        }
    }
}

New-AzConsumptionBudget @budget
```

**Phase 3 Deliverables**:
- Content safety integration (blocked inappropriate query)
- Rate limiting policies (user gets 429 at 1001st request)
- Audit logging (100% request capture, 7-year retention)
- Cost tracking dashboard (real-time spend visibility)
- IT-SG333 compliance report (passed audit)

**Success Criteria**:
- Content safety blocks 100% of test inappropriate queries (0 false negatives)
- Rate limiting enforces budget ($100/month per department)
- Audit logs capture 100% of requests (0 gaps)
- Cost alert triggered at $80 and $100 thresholds

---

### Phase 4: Production Scale (Week 7-10)

**Goal**: Production-ready deployment for 1000+ users

#### Deployment Architecture

**EVA Face** (Public-facing):
- Azure App Service (Standard tier, $200/month)
- Azure API Management (Standard tier, $500/month)
- Azure Front Door (WAF, DDoS protection)
- Multi-region: Canada East + Canada Central
- Auto-scaling: 2-10 instances based on CPU/memory

**EVA Chat** (Internal):
- Existing OpenWebUI deployment in EVAChatStgRg
- Private endpoint (HCCLD2 VNet)
- No changes required (stable)

**EVA Domain Assistant** (Internal):
- Existing MS Info Assistant deployments (infoasst-dev0 to infoasst-dev3, infoasst-stg1 to infoasst-stg3)
- Private endpoints (HCCLD2 VNet)
- No changes required (stable)

#### Load Testing Scenarios

**Scenario 1: Concurrent Users**
- 100 simultaneous chat requests
- Expected: <2s p95 latency, 0% errors
- Tool: Azure Load Testing

**Scenario 2: Sustained Load**
- 10 requests/second for 1 hour
- Expected: <3s p95 latency, <1% errors
- Auto-scaling triggers at 70% CPU

**Scenario 3: Spike Test**
- 0 → 500 users in 10 seconds
- Expected: Graceful degradation, no crashes
- Queue overflow handling

**Scenario 4: Backend Failover**
- Simulate EVA Chat offline
- Expected: Requests route to EVA Domain Assistant (degraded mode)
- Recovery time: <30 seconds

#### Disaster Recovery

**RTO/RPO**:
- Recovery Time Objective (RTO): 30 minutes
- Recovery Point Objective (RPO): 5 minutes

**Backup Strategy**:
- EVA Face configuration: Daily snapshot to Azure Blob
- Routing rules: Git repository (version controlled)
- Audit logs: Geo-replicated Cosmos DB

**Failover Plan**:
1. Detect failure (health check fails 3x in 1 minute)
2. Redirect traffic to secondary region (Azure Front Door)
3. Notify on-call engineer
4. Investigate root cause
5. Restore primary region
6. Fail back when stable

#### User Onboarding

**Target**: 1000+ users across ESDC

**Onboarding Flow**:
1. User requests access via ESDC portal
2. Manager approves (email notification)
3. User added to Azure AD group
4. Provisioned with principal ID
5. Welcome email with quick start guide
6. Training video (5 minutes)
7. Browser extension/CLI installation

**Training Materials**:
- Video: "Using EVA Face for General Chat" (3 minutes)
- Video: "Using EVA Face for Document Q&A" (5 minutes)
- PDF: "Quick Reference Guide" (2 pages)
- FAQ: Common questions (10 Q&A)

**Support**:
- Helpdesk: eva-support@gc.ca
- Teams channel: #eva-face-support
- Ticketing system: ServiceNow integration

**Phase 4 Deliverables**:
- Load test report (100 concurrent users validated)
- Multi-region deployment (Canada East + Central)
- Disaster recovery runbook (tested)
- Performance optimization report (<2s p95 latency achieved)
- Training materials (videos, PDFs, FAQ)
- User onboarding portal (1000+ users provisioned)

**Success Criteria**:
- 99.9% uptime over 30 days
- <2s p95 latency under 100 concurrent users
- $5,000/month total cost (within budget)
- 20+ applications integrated
- 1000+ users onboarded
- Zero data leakage incidents
- Zero unplanned outages

---

## PART 4: TECHNICAL SPECIFICATIONS

### EVA Face API Contract

**OpenAPI 3.0 Specification**:

```yaml
openapi: 3.0.0
info:
  title: EVA Face API
  version: 1.0.0
  description: Universal API gateway for EVA AI services

servers:
  - url: https://eva-face.gc.ca
    description: Production

paths:
  /health:
    get:
      summary: Aggregate health check
      responses:
        '200':
          description: All backends healthy
          content:
            application/json:
              schema:
                type: object
                properties:
                  status:
                    type: string
                    example: healthy
                  backends:
                    type: object
                    properties:
                      eva_chat:
                        type: string
                        example: healthy
                      eva_domain:
                        type: string
                        example: healthy
  
  /chat:
    post:
      summary: Chat with EVA AI
      description: Intelligently routes to EVA Chat or EVA Domain Assistant
      security:
        - EntraID: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                question:
                  type: string
                  example: "What is EI misconduct?"
                selectedFolders:
                  type: array
                  items:
                    type: string
                  example: ["proj1"]
                context:
                  type: string
                  enum: [general, jurisprudence]
                  example: "general"
                useRAG:
                  type: boolean
                  example: false
      responses:
        '200':
          description: Chat response
          content:
            application/json:
              schema:
                type: object
                properties:
                  answer:
                    type: string
                  citations:
                    type: array
                    items:
                      type: object
                  backend:
                    type: string
                    enum: [eva_chat, eva_domain]
        '400':
          description: Content policy violation
        '429':
          description: Rate limit exceeded
        '503':
          description: All backends unavailable

securitySchemes:
  EntraID:
    type: apiKey
    in: header
    name: x-ms-client-principal-id
```

---

### Environment Variables

**EVA Face Gateway**:
```bash
# Backend routing
EVA_CHAT_URL=https://evachat-stg.azurewebsites.net
EVA_DOMAIN_URL=https://infoasst-web-dev2.azurewebsites.net

# Azure services
AZURE_CLIENT_ID=<managed-identity-id>
CONTENT_SAFETY_ENDPOINT=https://esdaicoe-content-safety.cognitiveservices.azure.com
COSMOS_ENDPOINT=https://eva-face-audit.documents.azure.com
COSMOS_DATABASE=audit

# Governance
RATE_LIMIT_REQUESTS_PER_DAY=1000
COST_THRESHOLD_WARNING=80
COST_THRESHOLD_ALERT=100

# Feature flags
ENABLE_CONTENT_SAFETY=true
ENABLE_RATE_LIMITING=true
ENABLE_AUDIT_LOGGING=true
```

---

## PART 5: COST ANALYSIS

### Monthly Operating Costs

| Component | Service | SKU | Quantity | Monthly Cost |
|-----------|---------|-----|----------|--------------|
| **EVA Face Gateway** | Container Apps | Consumption | 1 | $50 |
| **EVA Face Gateway (Prod)** | App Service | Standard S1 | 2 instances | $200 |
| **API Management** | APIM | Standard | 1 | $500 |
| **Azure Front Door** | AFD Standard | 1 | $35 |
| **Content Safety** | Cognitive Services | S0 | Pay-per-use | $50 |
| **Cosmos DB Audit** | Cosmos DB | Provisioned 400 RU/s | 1 | $24 |
| **Application Insights** | Monitor | Pay-per-GB | ~10 GB | $23 |
| **Load Testing** | Azure Load Testing | Pay-per-VUH | One-time | $100 |
| **EVA Chat** | Existing | N/A | N/A | $0 (no change) |
| **EVA Domain Assistant** | Existing | N/A | N/A | $0 (no change) |
| **Shared Azure OpenAI** | Existing | N/A | N/A | $0 (allocated to backends) |

**Total New Costs**: $882/month operational  
**One-Time Costs**: $100 (load testing)  
**Total Budget**: $5,000/month (includes existing EVA Chat + EVA Domain Assistant $4,000/month)

**Cost Optimization**:
- Container Apps Consumption tier for dev/stage ($50/month)
- Standard App Service tier for production (balance cost/performance)
- APIM Standard tier (sufficient for <10M requests/month)
- Content Safety pay-per-use (only charged for actual usage)

---

## PART 6: RISK ASSESSMENT

### Critical Risks

**Risk 1: EsPAICoESub Production Inventory Unknown**
- **Probability**: LOW (production systems expected to mirror dev/stage)
- **Impact**: HIGH (cannot validate production architecture)
- **Mitigation**: 
  - Obtain EsPAICoESub inventory ASAP (user stated "will get soon")
  - Assume parity with EsDAICoESub until confirmed
  - Plan for differences (e.g., different resource names, additional security)

**Risk 2: EVA Chat Architecture Assumptions**
- **Probability**: MEDIUM (limited evidence, only storage accounts discovered)
- **Impact**: MEDIUM (routing logic may need adjustment)
- **Mitigation**:
  - Inspect EVAChatDevRg and EVAChatStgRg resources directly
  - Review OpenWebUI deployment configuration
  - Validate API contracts before Phase 1 gateway build

**Risk 3: Governance Complexity**
- **Probability**: HIGH (multiple systems to integrate)
- **Impact**: MEDIUM (compliance delays)
- **Mitigation**:
  - Start governance hooks in Phase 1 (logging, telemetry)
  - Engage IT Security early (Week 1)
  - Use existing ESDC patterns (Azure Monitor, Cost Management)

**Risk 4: Private Endpoint Access (HCCLD2)**
- **Probability**: MEDIUM (many services have private endpoints)
- **Impact**: HIGH (cannot access from local dev)
- **Mitigation**:
  - Use Microsoft DevBox for secure development
  - Fallback mode for local dev (public endpoints when available)
  - Document VPN + DevBox setup in onboarding guide

**Risk 5: RBAC Permissions**
- **Probability**: MEDIUM (functional tests showed 8/12 services blocked)
- **Impact**: MEDIUM (cannot list keys for testing)
- **Mitigation**:
  - Use Azure AD authentication (preferred, no keys required)
  - Request elevated permissions for operational testing
  - Document permission requirements in deployment guide

---

## PART 7: SUCCESS METRICS

### Phase-by-Phase KPIs

| Phase | Key Metric | Target | Measurement Method |
|-------|------------|--------|-------------------|
| **Phase 0** | Infrastructure documented | 100% | Evidence cache analyzed ✅ |
| **Phase 1** | EVA Face latency overhead | <10ms | Smoke test latency comparison |
| **Phase 1** | API compatibility | 100% | Smoke test pass rate |
| **Phase 2** | Client types deployed | 3 | Browser + COBOL + PowerShell |
| **Phase 2** | Browser extension installs | 50+ | Chrome Web Store analytics |
| **Phase 2** | COBOL integration pilots | 1 dept | Production batch job success |
| **Phase 2** | PowerShell CLI users | 20+ | NuGet download count |
| **Phase 3** | Content safety block rate | 100% | Test inappropriate queries blocked |
| **Phase 3** | Rate limit enforcement | 100% | User receives 429 at limit |
| **Phase 3** | Audit log coverage | 100% | Request count vs. log count |
| **Phase 3** | Cost alert accuracy | 100% | Alert triggered at threshold |
| **Phase 4** | Production uptime | 99.9% | Azure Monitor availability |
| **Phase 4** | Concurrent users | 100 | Load test validation |
| **Phase 4** | Latency p95 | <2s | Application Insights metrics |
| **Phase 4** | Total cost | <$5k/month | Azure Cost Management |
| **Phase 4** | User onboarding | 1000+ | Azure AD group membership |
| **Phase 4** | Application integrations | 20+ | API usage telemetry |

---

## PART 8: NEXT ACTIONS

### Immediate (This Week)

1. **Obtain EsPAICoESub Production Inventory** 🚨 CRITICAL
   ```powershell
   cd I:\eva-foundation\system-analysis\inventory
   .\Get-AzureInventory.ps1 -Subscription "EsPAICoESub"
   ```
   **Purpose**: Confirm production architecture, validate assumptions

2. **Inspect EVA Chat Resources**
   ```powershell
   az resource list --resource-group EVAChatStgRg --output table
   az resource list --resource-group EVAChatDevRg --output table
   ```
   **Purpose**: Discover missing components (web app, database, etc.)

3. **Validate API Contracts**
   ```powershell
   # Test EVA Chat endpoint (if discovered)
   Invoke-RestMethod -Uri "https://evachat-stg.azurewebsites.net/health"
   
   # Test EVA Domain Assistant endpoint (known working)
   Invoke-RestMethod -Uri "https://infoasst-web-dev2.azurewebsites.net/health"
   ```
   **Purpose**: Confirm API compatibility before gateway build

4. **Review This Scaffold Plan**
   - Validate architecture against actual vision
   - Confirm routing strategy aligns with use cases
   - Adjust Phase 1-4 deliverables if needed

---

### Short-term (Week 1-2)

**If EsPAICoESub inventory confirms architecture**:

1. Create EVA Face repository (GitHub)
2. Scaffold Python/Quart gateway (500 lines)
3. Implement routing logic (EVA Chat vs. EVA Domain)
4. Add authentication passthrough
5. Deploy to Azure Container Apps (dev environment)
6. Run smoke test against EVA Face
7. Validate <10ms latency overhead

**Deliverables**:
- EVA Face codebase
- Docker container
- Azure deployment
- Smoke test passing

---

### Medium-term (Week 3-6)

**Phase 2: Multi-Client Deployment**:
- Browser extension (TypeScript, Manifest V3)
- COBOL integration (JCL example)
- PowerShell CLI (module)
- User adoption validation

**Phase 3: Governance Integration**:
- Content safety (Azure Content Safety)
- Rate limiting (APIM policies)
- Cost tracking (Azure Cost Management)
- Audit logging (Cosmos DB)
- IT-SG333 compliance validation

---

### Long-term (Week 7-10)

**Phase 4: Production Scale**:
- Load testing (100 concurrent users)
- Multi-region deployment
- Disaster recovery testing
- Performance optimization
- User onboarding (1000+ users)
- Training and documentation

---

## CONCLUSION

**What We Know**:
- ✅ Two distinct EVA systems deployed (EVA Chat, EVA Domain Assistant)
- ✅ Complete architecture documented (infoasst-dev2: 63 resources)
- ✅ Azure OpenAI functional access validated
- ✅ Private endpoint security pattern confirmed

**What We Need**:
- 🚨 EsPAICoESub production inventory (CRITICAL)
- ⚠️ EVA Chat complete architecture (partial evidence)
- ⚠️ API contract validation (both backends)

**Strategic Value**:
- EVA Face enables ANY client to access AI intelligence
- Legacy COBOL systems get AI without modernization
- Browser-based workflows gain contextual intelligence
- Governance enforced at the edge (compliance by design)
- AICOE maintains intelligence, organization deploys facades

**Budget**: $5,000/month total ($882/month new, $4,000/month existing)

**Timeline**: 10 weeks (Phase 0 ✅ → Phase 4)

**Decision Point**: Obtain EsPAICoESub inventory to confirm production architecture, then proceed to Phase 1 (EVA Face Gateway build).

---

**Contact**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Repository**: I:\eva-foundation\24-eva-brain  
**Evidence**: I:\eva-foundation\system-analysis\inventory\.eva-cache  
**Last Updated**: February 3, 2026

**Next Command**: Get production inventory 🚀
```powershell
cd I:\eva-foundation\system-analysis\inventory
.\Get-AzureInventory.ps1 -Subscription "EsPAICoESub" -OutputDir ".eva-cache"
```
