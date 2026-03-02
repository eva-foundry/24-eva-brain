# EVA Face - Universal API Facade Strategy

**Strategic Vision**: Deploy AI intelligence anywhere, from 1980s legacy systems to modern browsers, while enforcing governance at the edge.

---

## The Complete EVA Ecosystem

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORGANIZATION-WIDE CLIENTS                     │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Browser   │  │   Legacy    │  │   Modern    │            │
│  │  Extension  │  │  1980s App  │  │   WebApp    │            │
│  │  (Chrome)   │  │  (COBOL)    │  │  (React)    │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         │                 │                 │                    │
│         └─────────────────┼─────────────────┘                   │
│                           │                                      │
│                           ▼                                      │
│              ┌────────────────────────────┐                     │
│              │      EVA FACE (Facade)     │                     │
│              │  ─────────────────────────│                     │
│              │  • API Gateway (APIM)     │                     │
│              │  • Authentication         │                     │
│              │  • Rate Limiting          │                     │
│              │  • AI Governance          │                     │
│              │  • IT-SG333 Compliance    │                     │
│              │  • Telemetry/Monitoring   │                     │
│              └────────────┬───────────────┘                     │
│                           │                                      │
│                           ▼                                      │
│              ┌────────────────────────────┐                     │
│              │    EVA BRAIN (Backend)     │                     │
│              │  ─────────────────────────│                     │
│              │  • Chat API (/chat)       │                     │
│              │  • RAG API (/chat+docs)   │                     │
│              │  • Sessions (/sessions)   │                     │
│              │  • GPT-4o Intelligence    │                     │
│              └────────────┬───────────────┘                     │
│                           │                                      │
│                           ▼                                      │
│              ┌────────────────────────────┐                     │
│              │   EVA PIPELINE (Enrichment)│                     │
│              │  ─────────────────────────│                     │
│              │  • Document OCR           │                     │
│              │  • Chunking/Embeddings    │                     │
│              │  • Azure Search Indexing  │                     │
│              └────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Strategic Value Proposition

### For AICOE (Center of Excellence)
**Maintain**: EVA Brain + EVA Pipeline (the intelligence)  
**Outsource**: EVA Face deployment (to business units)  
**Control**: Governance policies, security, AI models  
**Benefit**: Scale AI across organization without scaling team

### For Business Units
**Deploy**: EVA Face anywhere (browser, legacy apps, new apps)  
**Integrate**: Any system can call EVA APIs (REST/JSON)  
**Comply**: IT-SG333, AI governance enforced automatically  
**Benefit**: AI capabilities without AI expertise

### For Legacy Systems (1980s/2000s)
**No Modernization Required**: Call HTTP REST APIs  
**AI-Enabled**: COBOL, PowerBuilder, VB6 get GPT-4 access  
**Gradual Migration**: Add AI features without rewrite  
**Benefit**: Extend system lifespan, modern UX

---

## EVA Face Deployment Patterns

### Pattern 1: Browser Extension
```javascript
// Chrome Extension manifest.json
{
  "name": "EVA Face - AI Assistant",
  "permissions": ["activeTab"],
  "background": {
    "service_worker": "eva-face-client.js"
  }
}

// eva-face-client.js
async function askEVA(question) {
  const response = await fetch('https://eva-face.service.gc.ca/v1/chat', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + await getEntraIDToken(),
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      messages: [{ role: 'user', content: question }]
    })
  });
  return await response.json();
}
```

**Use Case**: Any internal website gets AI assistant overlay

---

### Pattern 2: Legacy System Integration (COBOL/PowerBuilder)
```cobol
* COBOL calling EVA Face via HTTP
IDENTIFICATION DIVISION.
PROGRAM-ID. EVA-CLIENT.

DATA DIVISION.
WORKING-STORAGE SECTION.
01  EVA-URL           PIC X(100) VALUE 
    'https://eva-face.service.gc.ca/v1/chat'.
01  EVA-REQUEST       PIC X(2000).
01  EVA-RESPONSE      PIC X(5000).
01  HTTP-STATUS       PIC 999.

PROCEDURE DIVISION.
    MOVE '{"messages":[{"role":"user","content":"What is EI?"}]}' 
         TO EVA-REQUEST
    CALL 'HTTP-POST' USING EVA-URL EVA-REQUEST EVA-RESPONSE HTTP-STATUS
    DISPLAY 'EVA Response: ' EVA-RESPONSE
    STOP RUN.
```

**Use Case**: 1980s mainframe systems get AI Q&A

---

### Pattern 3: Modern WebApp Integration
```typescript
// eva-face-sdk.ts (TypeScript SDK)
import { EVAFaceClient } from '@esdc/eva-face-sdk';

const eva = new EVAFaceClient({
  baseUrl: 'https://eva-face.service.gc.ca',
  auth: 'entra-id' // Automatic Entra ID token handling
});

// Simple chat
const answer = await eva.chat("What is Employment Insurance?");

// RAG query
const ragAnswer = await eva.chatWithDocs("PSHCP eligibility", {
  folders: ['proj1']
});

// Streaming
eva.chatStream("Explain EI misconduct", (chunk) => {
  console.log(chunk.content); // Token-by-token
});
```

**Use Case**: React/Vue/Angular apps with NPM package

---

### Pattern 4: Command-Line Integration
```powershell
# PowerShell calling EVA Face
$question = "What are the steps to apply for EI?"
$response = Invoke-RestMethod -Uri "https://eva-face.service.gc.ca/v1/chat" `
    -Method Post `
    -Headers @{
        "Authorization" = "Bearer $(az account get-access-token --query accessToken -o tsv)"
        "Content-Type" = "application/json"
    } `
    -Body (@{
        messages = @(@{
            role = "user"
            content = $question
        })
    } | ConvertTo-Json)

Write-Host $response.choices[0].message.content
```

**Use Case**: Batch scripts, automation, CI/CD pipelines

---

## EVA Face Architecture Components

### 1. API Gateway (Azure APIM)
- **Endpoint**: https://eva-face.service.gc.ca
- **Routing**: `/v1/chat` → EVA Brain backend
- **Versioning**: `/v1`, `/v2` (API evolution without breaking clients)
- **Rate Limiting**: 100 req/min per user (configurable by business unit)

### 2. Authentication Layer
- **Primary**: Entra ID (Azure AD) JWT tokens
- **Legacy**: API keys for systems that can't do OAuth
- **Service Principals**: For app-to-app integration
- **RBAC**: Role-based access (analyst, developer, admin)

### 3. Governance Enforcement
- **Content Safety**: Azure AI Content Safety API (block harmful prompts)
- **PII Detection**: Redact sensitive data before sending to EVA Brain
- **Audit Logging**: Every request logged to Log Analytics
- **Policy Enforcement**: AI governance rules (no external data, etc.)

### 4. Telemetry & Monitoring
- **Application Insights**: Request tracing, performance metrics
- **Cost Tracking**: Token usage per business unit (chargeback)
- **Usage Analytics**: Popular queries, error rates
- **Alerting**: Anomaly detection, budget thresholds

### 5. Security Controls (IT-SG333 Compliance)
- **Network**: Private endpoints only (no internet exposure)
- **Encryption**: TLS 1.3 in transit, AES-256 at rest
- **Secrets**: Azure Key Vault (no hardcoded keys)
- **Vulnerability Scanning**: Weekly scans, automated patching

---

## Deployment Strategy

### Phase 1: Pilot (Weeks 1-4)
**Deploy**: EVA Face in dev environment  
**Test**: Smoke test suite validates all APIs  
**Pilot Users**: AICOE team only (10 developers)  
**Success Criteria**: GO decision from smoke test

### Phase 2: Browser Extension (Weeks 5-8)
**Deploy**: Chrome/Edge extension to ESDC users  
**Target**: 100 pilot users (case managers, analysts)  
**Features**: Chat + RAG on any internal website  
**Success Criteria**: 80% adoption, < 5% error rate

### Phase 3: Legacy Integration (Weeks 9-16)
**Deploy**: EVA Face client libraries (COBOL, PowerBuilder, VB6)  
**Target**: 3 legacy systems (EI processing, PSHCP eligibility)  
**Features**: AI-powered data validation, Q&A help  
**Success Criteria**: 1+ legacy system in production

### Phase 4: Organization-Wide (Weeks 17-24)
**Deploy**: Self-service EVA Face SDK (NPM, NuGet, Maven)  
**Target**: All ESDC developers  
**Features**: Full API access, documentation, samples  
**Success Criteria**: 10+ applications using EVA Face

---

## Governance Framework Integration

### AI Governance (Project 19)
- **Policy Engine**: EVA Face enforces AI policies at gateway
- **Prompt Templates**: Pre-approved templates for sensitive use cases
- **Model Selection**: AICOE controls which models available
- **Data Classification**: Enforce data handling rules

### IT-SG333 (Security)
- **Network Segmentation**: EVA Face in secure zone
- **Access Control**: RBAC with Entra ID groups
- **Incident Response**: Automated threat detection
- **Compliance Reporting**: Quarterly security audits

### FinOps (Cost Management)
- **Cost Allocation**: Track usage by business unit
- **Budget Alerts**: Notify when approaching limits
- **Optimization**: Recommend caching, batch processing
- **Chargeback**: Transparent cost attribution

---

## The "Red Herring" Validation

**Smoke Test Purpose**: Prove APIs work independently

**Why It Matters**:
1. **Frontend Decoupling**: Any client can call EVA Brain → EVA Face viable
2. **Legacy Integration**: REST APIs work → 1980s systems can integrate
3. **Governance Insertion**: API calls logged → compliance enforceable
4. **Scale Validation**: RAG returns citations → intelligence layer operational

**Once Smoke Test Returns GO**:
- ✅ EVA Face architecture validated
- ✅ Deployment patterns proven
- ✅ Legacy integration feasible
- ✅ Organization-wide rollout ready

---

## Long-Term Vision (2-Year Roadmap)

### Year 1: Foundation
- **Q1**: EVA Brain operational (smoke test GO)
- **Q2**: EVA Face deployed (browser extension pilot)
- **Q3**: Legacy integration (3 systems)
- **Q4**: Organization-wide launch (50+ apps)

### Year 2: Scale & Governance
- **Q1**: Agentic capabilities (multi-turn conversations)
- **Q2**: AI governance automation (policy engine)
- **Q3**: Advanced RAG (multi-modal, real-time)
- **Q4**: Cross-government federation (share EVA with other departments)

### Year 3: Innovation
- **Agentic Workflows**: EVA orchestrates tasks across systems
- **Autonomous Operations**: EVA handles routine requests end-to-end
- **Knowledge Graph**: EVA builds organizational knowledge base
- **AI Teammates**: EVA becomes embedded in daily workflows

---

## Success Metrics

### Technical Metrics
- **Uptime**: 99.9% availability (EVA Face + EVA Brain)
- **Latency**: < 3s response time (p95)
- **Error Rate**: < 1% failed requests
- **Token Efficiency**: < $0.10 per conversation

### Business Metrics
- **Adoption**: 1000+ users by end of Year 1
- **Integration**: 20+ applications using EVA Face
- **Legacy Modernization**: 5+ 1980s systems AI-enabled
- **Cost Savings**: 30% reduction in support requests

### Governance Metrics
- **Compliance**: 100% requests logged and auditable
- **Security**: Zero breaches, quarterly audits pass
- **Policy Enforcement**: 100% AI policies enforced at gateway
- **Data Protection**: PII detection 99%+ accurate

---

## Competitive Advantage

**Why EVA Face is Unique**:
1. **Legacy Support**: Only solution that works with 1980s systems
2. **Governance-First**: Security/compliance built-in, not bolted-on
3. **ESDC-Specific**: Understands EI, PSHCP, CPPD domain knowledge
4. **Bilingual**: French/English with legal accuracy
5. **Private Cloud**: No data leaves Government of Canada

**vs. Commercial Solutions**:
- ❌ ChatGPT Enterprise: No legacy support, data residency concerns
- ❌ Microsoft Copilot: Limited RAG, no domain expertise
- ❌ AWS Bedrock: Complex setup, no governance framework
- ✅ EVA Face: Purpose-built for GC, works with everything

---

## Call to Action

### For AICOE Team
1. ✅ Run smoke test (validate APIs)
2. ⏳ Achieve GO decision (critical milestone)
3. 🚀 Deploy EVA Face pilot (browser extension)
4. 📈 Scale to organization (democratize AI)

### For Business Units
1. 📝 Identify legacy systems for AI integration
2. 🎯 Define use cases (Q&A, data validation, automation)
3. 🤝 Partner with AICOE (pilot deployment)
4. 🔄 Feedback loop (improve EVA capabilities)

### For Developers
1. 📚 Learn EVA Face SDK (TypeScript, PowerShell, COBOL)
2. 🛠️ Build integrations (start with browser extension)
3. 🧪 Test with smoke test suite (validate your client)
4. 🚢 Deploy to production (leverage EVA intelligence)

---

## Related Documentation

- **[README-DECOMPOSITION.md](./README-DECOMPOSITION.md)** - Architectural decomposition vision
- **[QUICK-REFERENCE.md](./QUICK-REFERENCE.md)** - Smoke test commands
- **[EVA-BRAIN-API-CONTRACTS.md](./EVA-BRAIN-API-CONTRACTS.md)** - Complete API specification
- **[EVA-BRAIN-END-TO-END-PLAN.md](./EVA-BRAIN-END-TO-END-PLAN.md)** - APIM, telemetry, FinOps

---

**The Long View**: EVA Face democratizes AI across the organization while AICOE maintains centralized governance. Legacy systems get AI without modernization. Every application becomes AI-powered. This is how ESDC becomes an AI-first organization.

---

**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Date**: February 3, 2026  
**Status**: Strategic Vision - Smoke Test Validation Phase  
**Next Milestone**: GO decision from smoke test → EVA Face pilot deployment 🚀

