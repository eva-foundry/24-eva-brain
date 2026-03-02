# Information Assistant Architecture Analysis & Agentic Improvements

> **Document Date**: February 8, 2026  
> **Project**: EVA Domain Assistant - Jurisprudence (EVA DA JP) v1.2  
> **Base**: Microsoft PubSec-Info-Assistant (Secure Mode)  
> **Status**: Production (EsPAICOESub), Sandbox Testing (EsDAICoE-Sandbox)

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [RBAC Multi-Tenancy Implementation](#rbac-multi-tenancy-implementation)
4. [Current Management Challenges](#current-management-challenges)
5. [Agentic Improvement Opportunities](#agentic-improvement-opportunities)
6. [Implementation Roadmap](#implementation-roadmap)
7. [References](#references)

## Executive Summary

**EVA DA JP 1.2** is a production-grade, secure-mode deployment of Microsoft's Public Sector Information Assistant template, customized to serve ESDC Service Officers for Employment Insurance claim processing. The implementation features a **50x RBAC-based multi-tenant architecture** with isolated indexes, storage containers, and role assignments per project/team.

### Key Statistics

| Metric | Count | Notes |
|--------|-------|-------|
| **Projects (Tenants)** | 50 | Each with isolated resources |
| **AI Search Indexes** | 50 | Format: `proj{N}-index` |
| **Storage Containers** | 100 | 50 upload + 50 content containers |
| **Group Mappings** | 150+ | Admin, Contributor, Reader per project |
| **Azure Functions** | 8 | Document processing pipeline |
| **App Services** | 3 | Backend, Enrichment, Functions |
| **Management Interfaces** | 0 | No admin UI for operations |

### Architecture Comparison: Original vs EVA JP 1.2

| Component | PubSec-Info-Assistant | EVA JP 1.2 |
|-----------|----------------------|------------|
| **Deployment Mode** | Standard or Secure | Secure Mode Only |
| **Multi-tenancy** | Single tenant | 50-tenant RBAC isolation |
| **Search Indexes** | 1 | 50 (proj1-index...proj50-index) |
| **Storage Architecture** | Shared containers | Isolated per-project containers |
| **RBAC Management** | Simple AAD groups | Complex groupmap in Cosmos DB |
| **Management Tools** | Basic UI + Azure Portal | No management UI, manual operations |
| **Enrichment Pipeline** | Single queue/processor | Multiplexed across 50 containers |
| **Operational Complexity** | Low | **Very High** |

### Critical Challenge

**There are no management screens or administrative interfaces** to:
- Monitor the health of 50 indexes
- View document processing status across projects
- Manage group/role assignments
- Troubleshoot enrichment pipeline issues
- Schedule maintenance or reindexing operations
- Analyze usage patterns or costs per project
- Perform bulk operations or migrations

This creates significant operational overhead and risk.

## Architecture Overview

### Base: Microsoft PubSec-Info-Assistant

The [PubSec-Info-Assistant](https://github.com/microsoft/PubSec-Info-Assistant) is Microsoft's open-source Generative AI solution template for public sector use cases. It implements:

- **RAG (Retrieval Augmented Generation)** pattern with Azure OpenAI
- **Azure AI Search** for hybrid vector + keyword search
- **Document Processing Pipeline** with Azure Functions
- **Secure Mode** with VNet isolation, private endpoints
- **Multi-modal Support** (text, images, PDFs, Office docs)
- **Content Safety** via Azure OpenAI content filtering

### Key Components

```
┌─────────────────────────────────────────────────────────────┐
│                    User Experience Layer                     │
│  - React/TypeScript Frontend (Vite)                         │
│  - FastAPI Backend (Python)                                  │
│  - Authentication: Azure AD (EasyAuth)                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Backend Services                        │
│  - Chat API (17 endpoints)                                  │
│  - Document Upload/Management                                │
│  - Session Management (Cosmos DB)                           │
│  - RBAC Resolution (custom utility_rbck.py)                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Processing Pipeline (Azure Functions)       │
│  1. FileUploadedTrigger    → Queue: file-uploaded          │
│  2. FileFormRecSubmission  → Azure Document Intelligence    │
│  3. FileFormRecPolling     → Poll OCR results              │
│  4. FileLayoutParsing      → Unstructured.io processing     │
│  5. TextEnrichment         → Queue: text-enrichment         │
│  6. ImageEnrichment        → Azure Vision captions          │
│  7. FileDeletion           → Cleanup timer                  │
│  8. AuthorityDocProcessor  → Custom document types          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Enrichment Service                         │
│  - Queue consumer (embeddings-queue)                        │
│  - Azure OpenAI Embeddings (text-embedding-ada-002)         │
│  - Batch chunk processing (120 chunks/batch)                │
│  - Multi-index uploader                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     Data Persistence                         │
│  - Azure AI Search: 50 hybrid indexes                       │
│  - Blob Storage: 100 containers (upload + content)          │
│  - Cosmos DB: Status logs, session state, RBAC groupmap     │
└─────────────────────────────────────────────────────────────┘
```

### Secure Mode Architecture

EVA JP 1.2 operates in **Secure Mode**, which adds:

- **Private Virtual Network** with subnet segmentation
- **Private Endpoints** for all Azure services
- **Network Security Groups** for traffic filtering
- **No Public Internet Access** to backend services
- **ExpressRoute/VPN** connectivity requirements
- **Azure Monitor & Application Insights** via AMPLS

**Network Architecture**: Single VNet (`x.x.x.0/24`) with 14 subnets for service isolation.

## RBAC Multi-Tenancy Implementation

### Overview

EVA JP 1.2 implements a **duplicative multi-tenancy model** where each project/team gets completely isolated resources:

```
Project 1 (Admin, Contributor, Reader groups)
  ├── proj1-upload     (upload container)
  ├── proj1-content    (content container)
  └── proj1-index      (AI Search index)

Project 2 (Admin, Contributor, Reader groups)
  ├── proj2-upload     (upload container)
  ├── proj2-content    (content container)
  └── proj2-index      (AI Search index)

...

Project 50 (Admin, Contributor, Reader groups)
  ├── proj50-upload    (upload container)
  ├── proj50-content   (content container)
  └── proj50-index     (AI Search index)
```

### Cosmos DB GroupMap Structure

The RBAC mapping is stored in Cosmos DB (`groupResourcesMapContainer`):

```json
{
  "id": "9f540c2e-e05c-4012-ba43-4846dabfaea6",
  "group_id": "9f540c2e-e05c-4012-ba43-4846dabfaea6",
  "group_name": "AICoE Playground Project 1 Admin",
  "upload_storage": {
    "upload_container": "proj1-upload",
    "role": "Storage Blob Data Owner"
  },
  "blob_access": {
    "blob_container": "proj1-content",
    "role_blob": "Storage Blob Data Owner"
  },
  "vector_index_access": {
    "index": "proj1-index",
    "role_index": "Search Index Data Contributor"
  }
}
```

**Each project has 3 groups**:
- Admin: Full ownership (Owner roles)
- Contributor: Read/write access
- Reader: Read-only access

**Total**: 50 projects × 3 roles = **150+ group mappings** in Cosmos DB.

### RBAC Resolution Process

1. **User Authentication**: Azure AD (EasyAuth) provides `x-ms-client-principal` header
2. **Group Extraction**: `decode_x_ms_client_principal()` extracts user's group memberships
3. **GroupMap Lookup**: Match user groups against Cosmos DB groupmap (cached)
4. **Role Priority**: If user in multiple groups, prioritize Admin > Contributor > Reader
5. **Resource Resolution**: Return project-specific container/index names + role
6. **Access Control**: Backend uses resolved resources for all operations

**Key Functions** (from `utility_rbck.py`):
- `find_grpid_ctrling_rbac()` - Determine controlling group ID
- `find_upload_container_and_role()` - Get upload container for user
- `find_container_and_role()` - Get content container for user
- `find_index_and_role()` - Get search index for user

### Pros and Cons

#### Advantages ✅
- **Strong Isolation**: Complete data separation per project
- **Granular RBAC**: Fine-grained role-based access control
- **Compliance**: Meets strict government data residency/isolation requirements
- **Scalability**: Each project independently scalable
- **Multi-org Support**: Can serve multiple organizations securely

#### Disadvantages ❌
- **Operational Complexity**: 50× the management overhead
- **Cost**: Duplicate storage, compute, search indexes
- **No Central Management**: No unified view of all projects
- **Manual Operations**: No tooling for bulk operations
- **Troubleshooting Difficulty**: Must check 50 indexes individually
- **Schema Evolution**: Schema changes require 50× deployments
- **Monitoring Gaps**: Hard to aggregate metrics across projects

### Authentication Flow

```python
# From app.py
def get_user_oid(request: Request) -> str:
    """
    Extract user OID from authentication headers.
    Priority:
    1. Azure AD (production) - x-ms-client-principal-id
    2. Test user (sandbox) - x-test-user-id from APIM
    3. Fallback for sandbox
    """
    auth_enabled = str_to_bool.get(ENV.get("AUTH_ENABLED", "false"))
    azure_env = ENV.get("AZURE_ENVIRONMENT", "sandbox").lower()
    
    # Production path...
    # APIM test path...
    # Fallback...
```

In production:
- User → Azure AD authentication
- Backend receives `x-ms-client-principal` (Base64-encoded JWT)
- Extract `groups` claim (list of AAD group IDs)
- Match against Cosmos groupmap → resolve to project resources

## Current Management Challenges

### 1. **No Administrative UI**

**Problem**: There is no management interface for:
- Viewing all 50 projects and their health status
- Monitoring document processing pipelines per project
- Managing RBAC group assignments
- Viewing usage statistics (document counts, query volumes)
- Troubleshooting errors across projects

**Impact**:
- Operations require manual Azure Portal navigation
- No unified dashboard for system health
- Difficult to identify failing projects quickly
- No self-service for team administrators

### 2. **Enrichment Pipeline Management**

**Problem**: The enrichment service processes documents for all 50 projects through shared queues:

```
embeddings-queue (shared)
  ↓
Enrichment Service (single instance)
  ↓
Routes to 50 different indexes based on upload container
```

**Challenges**:
- No visibility into per-project queue depths
- Cannot prioritize urgent projects
- Difficult to debug why a specific project's documents aren't processing
- No retry management or dead-letter queue handling per project
- Manual reprocessing requires direct queue manipulation

### 3. **Scheduling & Maintenance**

**Problem**: No centralized scheduling for:
- Index rebuilds or optimizations
- Document re-enrichment (when embedding models change)
- Cleanup of old documents
- RBAC audit and synchronization
- Cost analysis and reporting

**Current State**: All done manually or via ad-hoc scripts

### 4. **Monitoring & Observability**

**Problem**: Application Insights captures logs, but:
- No project-level aggregation views
- Cannot easily correlate errors across the pipeline for a project
- No alerting on per-project SLA violations
- Difficult to track document lifecycle (upload → enrichment → indexing)

### 5. **RBAC Group Management**

**Problem**: Adding a new project requires:
1. Create 3 Azure AD groups (Admin, Contributor, Reader)
2. Create 2 blob containers (upload, content)
3. Create 1 AI Search index
4. Assign RBAC roles on each resource
5. Update Cosmos DB groupmap with JSON entries
6. Update `examplelist.json` for UI
7. Test authentication and access

**Current Process**: Manual, error-prone, takes ~1-2 hours

### 6. **Document Status Tracking**

**Problem**: Document processing spans multiple Azure Functions:
- FileUploadedTrigger
- FileFormRecSubmission
- FileFormRecPolling
- FileLayoutParsing
- TextEnrichment
- ImageEnrichment

**Current Tracking**: Cosmos DB `statusLogs` container, but:
- No UI to view status across all projects
- Cannot filter by project, user, or date range
- No retry/reprocess buttons for failed documents
- Logs expire after retention period

### 7. **Cost Management**

**Problem**: 
- 50 AI Search indexes incur per-index costs
- Difficult to attribute costs per project
- No chargeback mechanism
- Cannot identify underutilized projects

**Needed**:
- Per-project cost reports
- Usage-based chargeback
- Recommendations for consolidation

### 8. **Backup & Disaster Recovery**

**Problem**:
- No centralized backup management for 50 indexes
- Cannot easily restore a single project
- No documented DR procedures per project

## Agentic Improvement Opportunities

### Philosophy: Management Orchestration via APIM + AI Agents

Rather than building traditional admin UI screens, leverage **AI agents** to:
- Understand natural language requests
- Execute complex operations across multiple projects
- Provide intelligent diagnostics and recommendations
- Automate routine management tasks

**Architecture Proposal**: 

```
┌─────────────────────────────────────────────────────────────┐
│           Management Interface (Natural Language)            │
│  - Teams Bot / Web Chat / API                               │
│  - "Show me all projects with failed documents today"        │
│  - "Restart enrichment for project 12"                       │
│  - "Add user X to project 5 as Contributor"                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Azure API Management (APIM)                 │
│  - Central gateway for management operations                │
│  - Policy enforcement (auth, rate limiting, logging)        │
│  - Request routing to agents or APIs                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    AI Management Agents                      │
│  1. Project Health Agent    - Monitor all projects          │
│  2. Document Pipeline Agent - Track processing status       │
│  3. RBAC Management Agent   - Group/role operations         │
│  4. Cost Analysis Agent     - Usage reports & optimization  │
│  5. Maintenance Agent       - Scheduling & operations       │
│  6. Diagnostic Agent        - Troubleshooting & root cause  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Backend Management APIs (New)                   │
│  - Project CRUD operations                                  │
│  - Bulk operations (reindex, cleanup, etc.)                 │
│  - Status aggregation across projects                       │
│  - Queue management (retry, purge, prioritize)              │
│  - RBAC synchronization with AAD                            │
└─────────────────────────────────────────────────────────────┘
```

### Agent 1: **Project Health Monitoring Agent**

**Purpose**: Provide real-time health overview of all 50 projects

**Capabilities**:
- "Show me all projects with errors in the last 24 hours"
- "Which projects have the most documents pending enrichment?"
- "Alert me if any project's index is >90% capacity"
- "Compare document processing times across projects"

**Implementation**:
- Query Application Insights for errors grouped by project
- Poll Azure AI Search for index statistics (document count, size)
- Check Cosmos DB status logs for failed documents per project
- Calculate SLAs: % documents processed within 5 minutes

**Tools/APIs Needed**:
- Application Insights Query API
- Azure AI Search Management API (for batch stats)
- Cosmos DB SDK (aggregate queries)
- Custom aggregation logic

**Output Example**:
```
Project Health Summary (Last 24 Hours)
========================================
🟢 42 projects healthy
🟡 6 projects with warnings
🔴 2 projects with errors

CRITICAL:
- Project 15: 23 documents failed enrichment (embedding API timeout)
- Project 33: Index storage 95% full

WARNINGS:
- Project 7: Slow enrichment (avg 8 min vs 3 min baseline)
- Project 21: 12 documents stuck in "Processing" state for >1 hour

Recommendations:
1. Investigate Project 15 embedding endpoint health
2. Increase index partition count for Project 33
3. Check queue backlog for Projects 7 and 21
```

### Agent 2: **Document Pipeline Orchestration Agent**

**Purpose**: Manage document processing lifecycle across 50 projects

**Capabilities**:
- "Reprocess all failed documents from last week for project 8"
- "Prioritize project 3's enrichment queue"
- "Show me documents uploaded by user X that haven't been indexed"
- "Cancel all pending processing for project 12"

**Implementation**:
- Track document state transitions via Cosmos DB
- Trigger Azure Functions via HTTP/Queue
- Manage queue priorities (Dead Letter Queue handling)
- Coordinate multi-step pipeline operations

**Tools/APIs Needed**:
- Azure Queue Storage SDK (read, write, purge, prioritize)
- Cosmos DB SDK (query status logs, update states)
- Azure Functions HTTP triggers (for reprocessing)
- Application Insights (pipeline observability)

**Output Example**:
```
Document Processing Report: Project 12
=======================================
Total Documents: 347
- ✅ Indexed:    312 (90%)
- ⏳ Processing: 15 (4.3%)
- ❌ Failed:     20 (5.7%)

Failed Documents Breakdown:
- 12 PDF extraction failures (Document Intelligence API 429 errors)
- 8 embedding generation failures (timeout)

Actions Available:
[1] Retry all failed documents
[2] Skip failed and mark as archived
[3] Download failure logs for investigation
[4] Notify project admin

Choose action [1-4]:
```

### Agent 3: **RBAC & Project Provisioning Agent**

**Purpose**: Automate project lifecycle and access management

**Capabilities**:
- "Create a new project called 'EI Claims - Region X' with 2 admins and 5 readers"
- "Add user sarah.jones@esdc.gc.ca to project 7 as Contributor"
- "Show me all users with access to project 15"
- "Decommission project 23 and archive its data"

**Implementation**:
- Azure AD Graph API (create groups, add members)
- Azure RBAC API (assign roles on storage/search)
- Cosmos DB SDK (update groupmap)
- Blob Storage SDK (create containers)
- AI Search SDK (create indexes from template)

**Workflow for New Project**:
```python
async def create_project(project_num: int, project_name: str, admins: List[str], contributors: List[str], readers: List[str]):
    # 1. Create Azure AD security groups
    admin_group = await aad.create_group(f"{project_name} Admin")
    contrib_group = await aad.create_group(f"{project_name} Contributor")
    reader_group = await aad.create_group(f"{project_name} Reader")
    
    # 2. Add members to groups
    await aad.add_members(admin_group.id, admins)
    await aad.add_members(contrib_group.id, contributors)
    await aad.add_members(reader_group.id, readers)
    
    # 3. Create storage containers
    await blob.create_container(f"proj{project_num}-upload")
    await blob.create_container(f"proj{project_num}-content")
    
    # 4. Assign RBAC roles
    await rbac.assign_role(f"proj{project_num}-upload", admin_group.id, "Storage Blob Data Owner")
    await rbac.assign_role(f"proj{project_num}-content", admin_group.id, "Storage Blob Data Owner")
    # ... (repeat for contributor, reader)
    
    # 5. Create AI Search index from template
    await search.create_index(f"proj{project_num}-index", template="evajp-hybrid-index-template")
    await rbac.assign_role(f"proj{project_num}-index", admin_group.id, "Search Index Data Contributor")
    
    # 6. Update Cosmos DB groupmap
    await cosmos.upsert_item({
        "id": admin_group.id,
        "group_id": admin_group.id,
        "group_name": f"{project_name} Admin",
        "upload_storage": {"upload_container": f"proj{project_num}-upload", "role": "Storage Blob Data Owner"},
        "blob_access": {"blob_container": f"proj{project_num}-content", "role_blob": "Storage Blob Data Owner"},
        "vector_index_access": {"index": f"proj{project_num}-index", "role_index": "Search Index Data Contributor"}
    })
    # ... (repeat for contributor, reader)
    
    # 7. Update examplelist.json
    await blob.update_config_blob("examplelist.json", add_project_examples(project_name, admin_group.id))
    
    return {"status": "success", "project_num": project_num, "project_name": project_name}
```

**Time Savings**: Manual process (2 hours) → Agent (2 minutes)

### Agent 4: **Cost Analysis & Optimization Agent**

**Purpose**: Provide cost insights and optimization recommendations

**Capabilities**:
- "What's the monthly cost breakdown for all 50 projects?"
- "Which projects have the highest storage costs?"
- "Identify underutilized projects (< 10 documents, no activity in 30 days)"
- "Estimate savings if we consolidate projects X, Y, Z"

**Implementation**:
- Azure Cost Management API
- AI Search metrics (document count, query volume)
- Blob Storage analytics (size, transaction count)
- Custom tagging strategy for per-project attribution

**Output Example**:
```
Monthly Cost Report (January 2026)
===================================
Total Spend: $8,750 CAD

Breakdown by Category:
- AI Search (50 indexes):  $4,200 (48%)
- Blob Storage:            $1,800 (21%)
- Azure OpenAI:            $1,500 (17%)
- Functions & App Services: $800 (9%)
- Cosmos DB:                $450 (5%)

Top 5 Projects by Cost:
1. Project 12: $425 (4,200 docs, 8,500 queries/month)
2. Project 3:  $380 (3,800 docs, 7,200 queries/month)
3. Project 7:  $310 (2,900 docs, 5,100 queries/month)
4. Project 18: $290 (2,700 docs, 4,800 queries/month)
5. Project 25: $265 (2,400 docs, 4,200 queries/month)

🚨 Optimization Opportunities:
- 8 projects have <50 documents and <100 queries/month
- Estimated savings: $680/month if consolidated into shared index
- Projects 34, 37, 41, 43, 45, 47, 49, 50 candidates for consolidation

Recommendation: Move low-activity projects to a "shared-small" index
with namespace-based segregation instead of separate indexes.
```

### Agent 5: **Maintenance & Operations Agent**

**Purpose**: Schedule and execute routine maintenance tasks

**Capabilities**:
- "Schedule a full reindex for project 5 this weekend"
- "Rebuild all indexes with updated schema (add new fields)"
- "Archive documents older than 2 years across all projects"
- "Run RBAC audit and report any inconsistencies"

**Implementation**:
- Azure Durable Functions (long-running orchestration)
- Scheduler (Azure Logic Apps or custom)
- AI Search Index rebuild APIs
- Backup/restore automation

**Maintenance Tasks**:

1. **Index Rebuild**:
   - Stop writes to index
   - Create new index with updated schema
   - Re-run enrichment pipeline to populate
   - Swap alias to new index
   - Delete old index

2. **Document Archival**:
   - Query Cosmos DB for old documents
   - Move blobs to Archive storage tier
   - Remove from search index
   - Update status logs

3. **RBAC Audit**:
   - Compare Cosmos groupmap vs AAD group memberships
   - Verify RBAC role assignments on resources
   - Report orphaned groups or resources

### Agent 6: **Intelligent Diagnostics Agent**

**Purpose**: Root cause analysis and troubleshooting assistance

**Capabilities**:
- "Why did project 8's documents fail to enrich yesterday?"
- "Diagnose slow query performance for project 12"
- "What's causing the spike in 429 errors?"
- "Predict if we'll hit index capacity limits this month"

**Implementation**:
- Application Insights advanced analytics
- Azure OpenAI for log analysis and pattern detection
- Historical data correlation
- Anomaly detection (Azure Monitor)

**Diagnostic Workflow**:
```
User: "Project 15 documents are stuck in 'Processing' state for 2 hours"

Agent Analysis:
1. Query Cosmos DB: 23 documents in "Processing" state for project 15
2. Check Application Insights: No enrichment service activity for "proj15-*" in last 2 hours
3. Inspect embeddings-queue: 0 messages for proj15-upload container
4. Check Azure Functions logs: FileLayoutParsing function failed for all proj15 docs
5. Error pattern: "UnstructuredIOError: Connection timeout to unstructured.io API"

Root Cause: Unstructured.io API endpoint is experiencing outage (429/503 errors)

Recommendations:
1. Enable Azure Function retry policy with exponential backoff (currently disabled)
2. Configure fallback parser (Azure Document Intelligence layout API)
3. Add health check pings for external dependencies
4. Immediate action: Requeue documents once API recovers (status: monitoring)

Estimated recovery time: API SLA 99.9% → expect resolution within 1 hour
```

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4) - **Foundation APIs**

**Goal**: Build management backend APIs and infrastructure

**Deliverables**:
1. **Management API Service** (FastAPI Python app)
   - Project CRUD endpoints
   - RBAC management endpoints
   - Status aggregation endpoints
   - Queue management endpoints

2. **APIM Configuration**
   - Management API product
   - Authentication policies (OAuth2 + AAD)
   - Rate limiting and throttling
   - Logging and monitoring

3. **Cosmos DB Extensions**
   - Add management metadata container
   - Aggregate queries and views
   - Caching layer improvements

4. **Monitoring Dashboards**
   - Azure Monitor workbooks for 50-project overview
   - Application Insights multi-project queries
   - Cost tracking setup (tagging strategy)

**Effort**: ~80 hours (2 engineers × 4 weeks)

### Phase 2: Core Agents (Weeks 5-10) - **Agents 1-3**

**Goal**: Deploy first 3 management agents

**Agent 1**: Project Health Monitoring
- Real-time health checks
- Alerting on anomalies
- SLA tracking

**Agent 2**: Document Pipeline Orchestration
- Retry/reprocess workflows
- Queue prioritization
- Pipeline diagnostics

**Agent 3**: RBAC & Project Provisioning
- Automated project creation
- User access management
- Group synchronization

**Tech Stack**:
- **Agent Framework**: Microsoft Agent Framework (Python)
- **LLM**: Azure OpenAI GPT-4o
- **Tools**: Custom Python functions calling Azure SDKs
- **Orchestration**: Multi-agent workflow via Agent Framework
- **Interface**: REST API + Teams bot

**Effort**: ~160 hours (2 engineers × 8 weeks)

### Phase 3: Advanced Agents (Weeks 11-16) - **Agents 4-6**

**Goal**: Deploy cost, maintenance, and diagnostics agents

**Agent 4**: Cost Analysis & Optimization
- Per-project cost attribution
- Consolidation recommendations
- Budgeting and forecasting

**Agent 5**: Maintenance & Operations
- Scheduled operations (reindex, cleanup)
- Schema evolution management
- Backup/restore automation

**Agent 6**: Intelligent Diagnostics
- Log analysis with LLM
- Root cause identification
- Predictive analytics

**Effort**: ~160 hours (2 engineers × 8 weeks)

### Phase 4: Integration & UI (Weeks 17-20)

**Goal**: User-facing interfaces and integration

**Deliverables**:
1. **Management Web Portal** (minimal, agent-driven)
   - Natural language command box
   - Project health dashboard
   - Document status viewer
   - RBAC management screens

2. **Microsoft Teams Bot**
   - Conversational interface for agents
   - Notifications and alerts
   - Approval workflows (for destructive operations)

3. **Documentation**
   - Admin guide for management agents
   - Runbooks for common tasks
   - API reference documentation

**Effort**: ~80 hours (2 engineers × 4 weeks)

### Total Timeline: **20 weeks (~5 months)**

### Resource Requirements

| Role | Commitment | Duration |
|------|-----------|----------|
| **Senior Backend Engineer** (Python, Azure) | Full-time | 20 weeks |
| **DevOps Engineer** (APIM, Azure, IaC) | Full-time | 12 weeks |
| **AI/ML Engineer** (Agent Framework, LLM) | Part-time (50%) | 16 weeks |
| **UX Designer** (for minimal UI) | Part-time (25%) | 8 weeks |

### Success Metrics

| Metric | Baseline (Now) | Target (Post-Implementation) |
|--------|---------------|------------------------------|
| **Time to provision new project** | 2 hours (manual) | 2 minutes (agent) |
| **Time to diagnose pipeline failure** | 30-60 minutes | 2-5 minutes |
| **Mean time to recovery (MTTR)** | Unknown (no central monitoring) | <15 minutes (with alerts) |
| **Operational overhead** | High (manual portal navigation) | Low (conversational interface) |
| **Cost visibility** | Poor (manual cost queries) | Excellent (automated reports) |
| **RBAC audit compliance** | Manual, quarterly | Automated, continuous |

## Technical Considerations

### Security & Compliance

1. **Agent Authentication**:
   - Managed Identity for agent-to-Azure service calls
   - OAuth2/AAD for user-to-agent authentication
   - No hardcoded secrets (Key Vault integration)

2. **Audit Logging**:
   - All agent actions logged to Cosmos DB
   - Immutable audit trail for compliance
   - Who/what/when for every operation

3. **Approval Workflows**:
   - Destructive operations require human approval
   - Multi-stage confirmations for critical actions
   - Rollback capabilities

### Scalability

1. **Caching Strategy**:
   - In-memory cache for groupmap (current: 5-minute TTL)
   - Redis cache for aggregated metrics
   - CDN for static UI assets

2. **Async Operations**:
   - All long-running tasks via Durable Functions
   - Status polling with webhooks
   - Background job queues

3. **Rate Limiting**:
   - APIM policies to prevent abuse
   - Per-user quotas
   - Throttling for bulk operations

### Observability

1. **Application Insights**:
   - Custom metrics per agent
   - Dependency tracking
   - Performance monitoring

2. **Distributed Tracing**:
   - OpenTelemetry instrumentation
   - Full request lifecycle tracking
   - Cross-service correlation

3. **Alerting**:
   - Azure Monitor alert rules
   - Teams/email notifications
   - PagerDuty integration for critical issues

## Alternative Approaches

### Option A: Traditional Admin UI

Build a React-based admin portal with CRUD screens for:
- Project management
- User/group management
- Document status viewer
- Cost dashboard

**Pros**: 
- Familiar UX pattern
- Direct visual feedback

**Cons**:
- Long development time (6+ months)
- High maintenance burden
- Less flexible (every new feature = new screen)
- Doesn't leverage AI capabilities

### Option B: CLI Tool

Build a command-line management tool (like Azure CLI):

```bash
evajp project list
evajp project create --name "Region X EI" --admins user1@esdc.gc.ca
evajp document reprocess --project 15 --status failed --date-range last-7-days
evajp rbac add-user --user sarah@esdc.gc.ca --project 7 --role Contributor
```

**Pros**:
- Fast to build
- Scriptable/automatable
- Low resource requirements

**Cons**:
- Steeper learning curve for non-technical admins
- No natural language interface
- Limited discoverability
- Requires terminal access

### Option C: Hybrid (Recommended)

Combine agents + minimal UI + CLI:
- **Agents**: Primary interface for complex operations, diagnostics
- **Minimal UI**: Dashboard views, quick actions
- **CLI**: For automation scripts, CI/CD integration

This provides flexibility while maximizing AI leverage.

## Next Steps

### Immediate Actions (Next 2 Weeks)

1. **Document current architecture** (✅ This document)
2. **Prioritize agent use cases** with stakeholders
3. **Set up development environment** for agent development
4. **Prototype Agent 1** (Project Health) with 5 projects as POC
5. **Design APIM API contracts** for management operations

### Governance

- **Weekly sync**: Review agent development progress
- **Bi-weekly demo**: Showcase working agents to stakeholders
- **Monthly review**: Assess ROI and adjust priorities

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Agent hallucinations** | Incorrect operations | Require confirmations, audit all actions, extensive testing |
| **Azure SDK breaking changes** | Agent tool failures | Pin SDK versions, automated testing, version tracking |
| **Adoption resistance** | Low usage | Training, gradual rollout, hybrid with traditional UI |
| **Cost overruns** | Budget exceeded | Incremental rollout, close monitoring, contingency budget |

## References

### Documentation

- [PubSec-Info-Assistant GitHub](https://github.com/microsoft/PubSec-Info-Assistant)
- [Azure AI Search Documentation](https://learn.microsoft.com/azure/search/)
- [Microsoft Agent Framework](https://github.com/microsoft/agent-framework)
- [Azure API Management](https://learn.microsoft.com/azure/api-management/)

### EVA JP 1.2 Artifacts

- Codebase: `C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2\`
- README: [EVA DA JP 1.2 README](C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2\README.md)
- RBAC Utility: [utility_rbck.py](C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2\functions\shared_code\utility_rbck.py)
- Backend: [app.py](C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2\app\backend\app.py)
- Enrichment: [app.py](C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2\app\enrichment\app.py)

### Architecture Diagrams

- Located in: `C:\AICOE\eva-foundation\24-eva-brain\info-asst-analysis\diagrams\`
- (To be created in next phase)

---

**Document Prepared By**: GitHub Copilot (Agent Mode)  
**Date**: February 8, 2026  
**Version**: 1.0  
**Status**: Draft for Review
