---
document_type: api_contract
phase: phase-0
audience: [architecture, engineering, security, operations]
traceability:
  - I:\EVA-JP-v1.2\app\backend\app.py
  - I:\EVA-JP-v1.2\app\frontend\src\api\api.ts
  - I:\EVA-JP-v1.2\app\frontend\src\api\models.ts
  - I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md
---

# EVA Brain API Contracts (As-Is)

## Architecture Overview

**Two Systems in Production**:

1. **Current EVA Chat** (https://chat.eva-ave.prv/)
   - Frontend: OpenWebUI (Svelte 5)
   - Backend: azure_openai_pipeline
   - Features: Standard chat, no RAG citations
   - Status: Production (not target for Spark PoC)

2. **EVA-JP (Jurisprudence)** (https://domain.eva.service.gc.ca/)
   - Frontend: React/TypeScript
   - Backend: Python/Quart with RAG
   - Features: Chat + RAG with document citations
   - Status: **TARGET FOR SPARK POC**

**This document focuses on EVA-JP backend contracts** (target system for GitHub Spark PoC).

## Scope

### In scope
- Chat endpoint specification (as implemented in IA backend)
- RAG endpoint specification (parameterized on chat endpoint)
- Authentication details from code references
- Request and response formats from frontend models

### Out of scope
- Public API exposure (prohibited by ITS07)
- New endpoints not present in the IA backend
- Any changes to production configuration

### Primary audience
- Architecture, engineering, security, operations

## As-Is Summary

- The IA backend exposes a single chat endpoint that supports both ungrounded and RAG modes via request parameters.
- Client request and response shapes are defined in the frontend models.
- The backend reads the authenticated user object id from the x-ms-client-principal-id header.

## Authentication Details

### Observed auth header
- Header: x-ms-client-principal-id
- Usage: Backend reads this header to resolve user context and group mappings.
- Example Value: fc1cf8cd-fce3-4ad5-bd16-58725f4e6a33 (user object ID from Entra ID)

### Development Mode
- For local development, frontend sets: `VITE_DEV_EASY_AUTH=true`
- Frontend provides: `X_MS_CLIENT_PRINCIPAL` (base64 JWT with user claims)
- Frontend provides: `X_MS_CLIENT_PRINCIPAL_ID` (user object ID)

### Evidence
- I:\EVA-JP-v1.2\app\backend\app.py:555 (header usage for /chat)
- I:\EVA-JP-v1.2\app\backend\routers\sessions.py:50 (header usage for sessions)
- I:\EVA-JP-v1.2\app\frontend\.env (dev auth configuration)
- I:\EVA-JP-v1.2\app\backend\backend.env (RBAC group configuration)

### Notes
- Production: App Service Easy Auth provides headers automatically
- Development: Frontend injects headers from .env file
- RBAC Groups: Backend checks user groups against SHOW_STRICTBOX and CPPD_GROUPS

## Chat Endpoint Specification (As-Is)

### Endpoint
- Method: POST
- Path: /chat
- Base URL (Local): http://localhost:5000
- Base URL (Production): https://infoasst-web-hccld2.azurewebsites.net
- Evidence: I:\EVA-JP-v1.2\app\backend\app.py:538

### Environment Configuration
```bash
# Backend (.env or backend.env)
AZURE_OPENAI_ENDPOINT=https://infoasst-aoai-hccld2.openai.azure.com/
AZURE_OPENAI_CHATGPT_DEPLOYMENT=gpt-4o
AZURE_SEARCH_SERVICE_ENDPOINT=https://infoasst-search-hccld2.search.windows.net/
COSMOSDB_URL=https://infoasst-cosmos-hccld2.documents.azure.com:443/
ENRICHMENT_APPSERVICE_URL=https://infoasst-enrichmentweb-hccld2.azurewebsites.net

# Frontend (.env)
VITE_DEV_EASY_AUTH=true  # Enable dev auth headers
X_MS_CLIENT_PRINCIPAL_ID=fc1cf8cd-fce3-4ad5-bd16-58725f4e6a33  # User OID
```

### Request format

The request body is JSON and matches the ChatRequest shape used by the frontend.

```json
{
  "history": [{"user": "string", "bot": "string"}],
  "approach": 0,
  "overrides": {
    "semanticRanker": true,
    "semanticCaptions": false,
    "excludeCategory": "string",
    "top": 5,
    "temperature": 0.3,
    "promptTemplate": "string",
    "promptTemplatePrefix": "string",
    "promptTemplateSuffix": "string",
    "suggestFollowupQuestions": false,
    "byPassRAG": false,
    "userPersona": "string",
    "isStrict": false,
    "systemPersona": "string",
    "aiPersona": "string",
    "responseLength": 0,
    "responseTemp": 0,
    "selectedFolders": "string",
    "selectedTags": "string",
    "pastRetrieved": 0,
    "session_id": "string"
  },
  "citation_lookup": {"key": {"citation": "string", "source_path": "string", "page_number": "string"}},
  "thought_chain": {"key": "string"}
}
```

### Request evidence
- I:\EVA-JP-v1.2\app\frontend\src\api\api.ts:33-64 (chatApi request construction)
- I:\EVA-JP-v1.2\app\frontend\src\api\models.ts:28-90 (ChatRequest and overrides)

### Response format

The response body is JSON and matches the ChatResponse shape used by the frontend.

```json
{
  "answer": "string",
  "thoughts": "string",
  "data_points": ["string"],
  "approach": 0,
  "thought_chain": {"key": "string"},
  "work_citation_lookup": {"key": {"citation": "string", "source_path": "string", "page_number": "string"}},
  "web_citation_lookup": {"key": {"citation": "string", "source_path": "string", "page_number": "string"}},
  "error": "string",
  "language": "string"
}
```

### Response evidence
- I:\EVA-JP-v1.2\app\frontend\src\api\models.ts:51-73 (ChatResponse)

## RAG Endpoint Specification (As-Is)

### RAG is parameterized on /chat

The IA backend does not expose a separate RAG endpoint. RAG behavior is controlled by the request body:
- approach: A RAG-capable approach (for example, ReadRetrieveRead or RetrieveThenRead)
- overrides.byPassRAG: false
- overrides.selectedFolders and overrides.selectedTags: drive scoped search for grounded answers

### Evidence
- I:\EVA-JP-v1.2\app\frontend\src\api\models.ts:5-27 (Approaches enum)
- I:\EVA-JP-v1.2\app\frontend\src\api\api.ts:36-63 (overrides mapping)
- I:\EVA-JP-v1.2\app\backend\app.py:560-610 (server-side handling of approach and overrides)

## Chat vs RAG Contract Table

| Mode | Endpoint | Required fields | Key overrides | Notes |
| --- | --- | --- | --- | --- |
| Ungrounded | /chat | history, approach | byPassRAG=true | Uses model without retrieval |
| RAG | /chat | history, approach | byPassRAG=false, selectedFolders, selectedTags | Uses search index and citations |

Note: The actual approach values are defined in Approaches enum in the frontend models. Use those numeric values when calling /chat.

## Constraints and Governance
Local Development
curl -X POST http://localhost:5000/chat `
  -H "Content-Type: application/json" `
  -H "x-ms-client-principal-id: fc1cf8cd-fce3-4ad5-bd16-58725f4e6a33" `
  -d '{"history":[{"user":"test"}],"approach":3,"overrides":{"byPassRAG":true},"citation_lookup":{},"thought_chain":{}}'

# Production (requires VPN/HCCLD2 access)
curl -X POST https://infoasst-web-hccld2.azurewebsites.net/chat `
  -H "Content-Type: application/json" `
  -H "x-ms-client-principal-id: fc1cf8cd-fce3-4ad5-bd16-58725f4e6a33" `
  -d '{"history":[{"user":"test"}],"approach":3,"overrides":{"byPassRAG":true},"citation_lookup":{},"thought_chain":{}}'
- Requirement IOP01 prohibits integration with internal applications beyond CSP and LLM interactions.
- Any APIM facade or external use must be handled as a requirements change.

## Implementation Evidence

- Requirement INF01 (I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md#L5-L8) defines access expectations.
- Requirement IOP01 (I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md#L54-L56) restricts integrations.
- Requirement ITS07 (I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md#L137-L138) prohibits external API exposure.
- Chat endpoint definition: I:\EVA-JP-v1.2\app\backend\app.py:538
- Request/response shapes: I:\EVA-JP-v1.2\app\frontend\src\api\api.ts:33-64 and I:\EVA-JP-v1.2\app\frontend\src\api\models.ts:28-73

## Validation Commands

```powershell
# Replace <BASE_URL> with your backend or APIM URL
curl -X POST <BASE_URL>/chat -H "Content-Type: application/json" -d "{}"
```

## Related Documentation

- I:\eva-foundation\24-eva-brain\EVA-BRAIN-END-TO-END-PLAN.md
- I:\eva-foundation\24-eva-brain\COPILOT-DISCOVERY-RUNBOOK.md
- I:\EVA-JP-v1.2\README.md
- I:\EVA-JP-v1.2\.github\copilot-instructions.md

## Production-Validated Examples

**Captured from**: https://domain.eva.service.gc.ca/ (February 2, 2026)

### Chat (RAG - PSHCP Eligibility Query)

**Request** (from browser DevTools):
```json
{
  "history": [{"user": "Who is eligible to enroll in the PSHCP?"}],
  "approach": 1,
  "overrides": {
    "byPassRAG": false,
    "selectedFolders": "proj1",
    "selectedTags": "",
    "top": 5,
    "semanticRanker": true
  },
  "citation_lookup": {},
  "thought_chain": {}
}
```

**Response** (initial metadata chunk):
```json
{
  "data_points": [
    "/infoasststoreprd1.blob.core.windows.net/proj1-upload/PSHCP_PSDCP/PSHCP-member-booklet.pdf| Table of Contents   The Public Service Health Care Plan (PSHCP)   Eligible employee (active member)    . You are a full-time or part-time federal public service employee appointed for more than 6 months..."
  ],
  "thought_chain": {
    "work_query": "Generate search query for: Who is eligible to enroll in the PSHCP?",
    "work_search_term": "PSHCP eligibility enroll"
  },
  "work_citation_lookup": {
    "File0": {
      "citation": "https://infoasststoreprd1.blob.core.windows.net/proj1-content/PSHCP_PSDCP/PSHCP-member-booklet.pdf/PSHCP-member-booklet-14.json",
      "source_path": "https://infoasststoreprd1.blob.core.windows.net/proj1-upload/PSHCP_PSDCP/PSHCP-member-booklet.pdf",
      "page_number": "9",
      "tags": ["PSHCP"]
    }
  },
  "web_citation_lookup": {},
  "language": "en"
}
```

**Streaming Response** (token-by-token):
```json
{"content": ""}
{"content": "The"}
{"content": " following"}
{"content": " individuals"}
{"content": " are"}
{"content": " eligible"}
// ...continues
{"content": " [File0] [File1] [File2] [File3] [File4]."}
{"content": null}  // End marker
```

### Chat (Ungrounded - Template)

```json
{
  "history": [{"user": "Example question"}],
  "approach": 3,
  "overrides": {
    "byPassRAG": true,
    "responseLength": 0,
    "responseTemp": 0
  },
  "citation_lookup": {},
  "thought_chain": {}
}
```

Notes:
- approach values are from Approaches enum in I:\EVA-JP-v1.2\app\frontend\src\api\models.ts
- Ungrounded uses GPTDirect (3). RAG example uses ReadRetrieveRead (1).
- selectedFolders should match a valid folder name in the UI or backend configuration.

## System Comparison

| Feature | Current EVA Chat (OpenWebUI) | EVA-JP (Target) |
|---------|------------------------------|------------------|
| **URL** | https://chat.eva-ave.prv/ | https://domain.eva.service.gc.ca/ |
| **Request Format** | `{model, messages[], chat_id}` | `{history[], approach, overrides}` |
| **Response Format** | Single JSON with full content | Metadata + streaming chunks |
| **RAG Support** | No document citations | Full RAG with `data_points` + `citation_lookup` |
| **Streaming** | Single response | SSE token-by-token |
| **Session Management** | `{chat_id, title, archived, pinned}` | `{session_id, user_id, group_name}` |
| **User Context** | `user_id` in chat object | `x-ms-client-principal-id` header |
| **Emoji Titles** | ✅ Auto-generated | ❌ Plain text |
| **Spark Target** | ❌ Not target | ✅ **Target for PoC** |

## Contract Validation Checklist

| Check | Description | Expected Result |
| --- | --- | --- |
| Content-Type | Request has Content-Type: application/json | 200 response or valid error | 
| Auth header present | x-ms-client-principal-id present (if required) | Authorized response | 
| Ungrounded mode | byPassRAG=true and approach=3 | Response with no citations | 
| RAG mode | byPassRAG=false and approach=1 | Response includes work_citation_lookup | 
| Folder scoping | selectedFolders=proj1 | Results scoped to proj1 | 
| Error handling | Invalid payload | error field populated or 4xx | 

## Postman Collection

- I:\eva-foundation\24-eva-brain\postman\EVA-BRAIN.postman_collection.json

