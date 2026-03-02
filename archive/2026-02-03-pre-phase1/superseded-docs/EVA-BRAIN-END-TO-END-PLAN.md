---
document_type: plan
phase: phase-0
audience: [architecture, engineering, operations, security, finops, devops]
traceability:
  - I:\EVA-JP-v1.2\README.md
  - I:\EVA-JP-v1.2\.github\copilot-instructions.md
  - I:\EVA-JP-v1.2\app\backend\app.py
  - I:\EVA-JP-v1.2\app\backend\routers\sessions.py
  - I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md
  - I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\04_eva_da_requirements.md
---

# EVA Brain End-to-End Plan (IA Backend, APIM, Telemetry, FinOps, DevOps)

## Scope

### In scope
- Map current IA backend API surface for EVA Brain reuse
- Define an APIM facade and versioned EVA API contract
- Propose cost and usage headers for traceable analytics
- Define telemetry pipeline to App Insights and Log Analytics
- Outline FinOps and DevOps analytics integrations

### Out of scope
- Implementing APIM or API changes in code in this document
- Creating public APIs without governance approval
- Production deployment changes without security review

### Primary audience
- Enterprise Architecture, platform engineering, security, FinOps, DevOps

## As-Is Baseline (Current Implementation)

### Current system shape
- IA backend provides internal APIs for its own frontend and system workflows.
- No external API exposure is allowed by requirement ITS07.
- No integration with internal applications is allowed by requirement IOP01.

### Current API endpoints (internal)

| Area | Endpoint | Method | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Health | /health | GET | I:\EVA-JP-v1.2\app\backend\app.py#L519 | Backend health check |
| Chat (SSE) | /chat | POST | I:\EVA-JP-v1.2\app\backend\app.py#L538 | Main chat entry point |
| Chat stream | /stream | GET | I:\EVA-JP-v1.2\app\backend\app.py#L1255 | Streaming output |
| Sessions | /sessions | POST | I:\EVA-JP-v1.2\app\backend\routers\sessions.py#L25 | Create session |
| Sessions history | /sessions/history | GET | I:\EVA-JP-v1.2\app\backend\routers\sessions.py#L68 | Retrieve history |
| Sessions history page | /sessions/history/page | GET | I:\EVA-JP-v1.2\app\backend\routers\sessions.py#L147 | Paged history |
| Sessions history write | /sessions/history | POST | I:\EVA-JP-v1.2\app\backend\routers\sessions.py#L249 | Store history |
| Sessions by id | /sessions/{session_id} | GET | I:\EVA-JP-v1.2\app\backend\routers\sessions.py#L348 | Read session |
| Sessions delete | /sessions/{session_id} | DELETE | I:\EVA-JP-v1.2\app\backend\routers\sessions.py#L394 | Delete session |
| File upload | /file | POST | I:\EVA-JP-v1.2\app\backend\app.py#L1442 | Upload content |
| File download | /get-file | POST | I:\EVA-JP-v1.2\app\backend\app.py#L1497 | Retrieve file |
| Translation | /translate-file | POST | I:\EVA-JP-v1.2\app\backend\app.py#L2254 | Translate file |

## Target Concept (Future / Not Implemented)

### EVA Brain as a backend platform
- EVA Brain remains a backend-only service that exposes a stable API contract.
- New chat or domain apps (for example, SPARK apps) call EVA Brain via APIM.
- APIM provides authentication, throttling, telemetry, and header injection.

### Governance note
- This target concept conflicts with ITS07 (no external API exposure) and IOP01 (no internal app integration).
- Any APIM exposure must remain internal-only or be approved as a requirement change.

## End-to-End Plan

| Step | Outcome | Key work items | Dependencies | Requirement alignment |
| --- | --- | --- | --- | --- |
| 1. Inventory and classification | Clear map of internal IA APIs | Confirm endpoints, auth flow, payloads, error shape | I:\EVA-JP-v1.2\app\backend\app.py | INF01, IOP01, ITS07 |
| 2. EVA Brain API contract | Versioned facade spec | Define /v1 routes, request and response schemas | Step 1 | INF01, ITS07 |
| 3. APIM facade design | APIM spec and policies | Auth, rate limit, header injection, versioning | Step 2 | ITS01, ITS07 |
| 4. Instrumentation | Cost and usage data model | Correlation ID, client app ID, cost center headers | Step 3 | OPS, FIN (proposed) |
| 5. Analytics pipeline | Central visibility | APIM + App Insights + Log Analytics + KQL | Step 4 | OPS, FIN (proposed) |
| 6. FinOps and DevOps integration | Cost and workload governance | Cost allocation, budget reporting, CI/CD dashboards | Step 5 | OPS, FIN (proposed) |

Note: OPS and FIN requirement IDs are not present in v0.2 files loaded for this plan. If they exist, update this table with the exact IDs and source links.

## Proposed EVA Brain API Facade (Versioned)

| Facade route | Method | Backing endpoint | Purpose | Exposure |
| --- | --- | --- | --- | --- |
| /v1/health | GET | /health | Liveness check | Internal-only |
| /v1/chat | POST | /chat | Primary chat | Internal-only |
| /v1/chat/stream | GET | /stream | Server-sent events | Internal-only |
| /v1/sessions | POST | /sessions | Create session | Internal-only |
| /v1/sessions/history | GET | /sessions/history | Retrieve history | Internal-only |
| /v1/sessions/history | POST | /sessions/history | Store history | Internal-only |
| /v1/sessions/{id} | GET | /sessions/{session_id} | Retrieve session | Internal-only |
| /v1/sessions/{id} | DELETE | /sessions/{session_id} | Delete session | Internal-only |
| /v1/files | POST | /file | Upload file | Internal-only |
| /v1/files/get | POST | /get-file | Download file | Internal-only |
| /v1/files/translate | POST | /translate-file | Translate file | Internal-only |

## APIM Facade Design (Proposed)

### Core policies
- Entra ID JWT validation
- Rate limiting per client app
- Request and response size caps
- Correlation ID enforcement
- Header injection for costing and analytics

### Proposed cost and usage headers

| Header | Source | Purpose |
| --- | --- | --- |
| x-eva-correlation-id | APIM | Trace request across services |
| x-eva-client-app-id | Client | Identify calling app |
| x-eva-cost-center | Client | Cost allocation (FinOps) |
| x-eva-workload | Client | Workload taxonomy |
| x-eva-user-id-hash | APIM | Privacy-safe user tracking |

## Telemetry and Analytics Plan (Proposed)

### Data flow
1. APIM logs request metadata and custom headers.
2. Backend logs correlation ID and request status.
3. App Insights and Log Analytics store all telemetry.
4. FinOps and DevOps dashboards query Log Analytics using KQL.

### Minimal analytics schema

| Field | Source | Use |
| --- | --- | --- |
| correlation_id | APIM and backend | End-to-end trace |
| client_app_id | APIM | Cost allocation by app |
| workload | APIM | Cost allocation by workload |
| endpoint | APIM | Usage per API |
| latency_ms | APIM and backend | Performance analysis |
| status_code | APIM and backend | Reliability |

## Risks and Constraints

| Risk | Impact | Mitigation | Requirement |
| --- | --- | --- | --- |
| External API exposure conflicts with ITS07 | High | Keep APIM internal-only or seek requirement change | ITS07 |
| Integration with internal apps conflicts with IOP01 | High | Limit to EVA-controlled apps or update requirements | IOP01 |
| Missing requirement IDs for ops and finops | Medium | Locate v0.2 requirement source and update | N/A |

## Implementation Evidence

- Requirement INF01 (I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md#L5-L8) defines access expectations.
- Requirement IOP01 (I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md#L54-L56) restricts integrations.
- Requirement ITS07 (I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md#L137-L138) prohibits external API exposure.
- IA backend routes are defined in I:\EVA-JP-v1.2\app\backend\app.py and I:\EVA-JP-v1.2\app\backend\routers\sessions.py.

## Validation Commands

```powershell
# Verify backend health (replace with actual base URL)
curl https://<BACKEND_BASE_URL>/health

# List APIM instances to identify the correct name and resource group
az apim list --query "[].{name:name, rg:resourceGroup}" -o table

# Validate APIM APIs once provisioned
az apim api list --resource-group <RESOURCE_GROUP_NAME> --service-name <APIM_NAME> -o table
```

## Related Documentation

- I:\EVA-JP-v1.2\README.md
- I:\EVA-JP-v1.2\.github\copilot-instructions.md
- I:\eva-foundation\README.md
- I:\eva-foundation\11-MS-InfoJP\README.md
- I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md
- I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\04_eva_da_requirements.md
