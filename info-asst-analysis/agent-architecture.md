# Agent Architecture Design

## Overview

This document details the technical architecture for the 6 proposed management agents.

## Technology Stack

### Core Framework
- **Agent Framework**: Microsoft Agent Framework (Python)
- **LLM**: Azure OpenAI GPT-4o (gpt-4o-2024-05-13)
- **Embeddings**: text-embedding-3-large (for semantic search over logs)
- **Orchestration**: Multi-agent workflows via Agent Framework

### Azure Services
- **API Gateway**: Azure API Management (APIM)
- **Compute**: Azure App Service (Linux, Python 3.11)
- **Data Sources**:
  - Cosmos DB (groupmap, status logs, audit logs)
  - Azure AI Search (50 indexes for monitoring)
  - Blob Storage (100 containers for operations)
  - Application Insights (telemetry, logs)
  - Azure Cost Management API
- **Authentication**: Azure AD + Managed Identity
- **Secrets**: Azure Key Vault

### Development Tools
- **IDE**: VS Code with AI Toolkit extension
- **Debugging**: Agent Inspector (integrated with AI Toolkit)
- **Testing**: pytest with agent mocking
- **CI/CD**: Azure DevOps or GitHub Actions

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      User Interfaces                         │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │  Web Portal  │  │  Teams Bot   │  │  REST API/CLI   │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬────────┘  │
└─────────┼──────────────────┼───────────────────┼───────────┘
          │                  │                   │
          └──────────────────┴───────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                 Azure API Management (APIM)                  │
│  - Authentication (OAuth2/AAD)                              │
│  - Rate limiting & throttling                               │
│  - Request validation & logging                             │
│  - Policy enforcement (RBAC, quotas)                        │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              Agent Orchestration Layer (FastAPI)             │
│  - Intent classification                                    │
│  - Agent selection & routing                                │
│  - Multi-agent coordination                                 │
│  - Response formatting                                      │
└────────────────────────────┬────────────────────────────────┘
                             │
          ┌─────────────────┬┴─────────────┬─────────────┐
          │                 │              │             │
          ▼                 ▼              ▼             ▼
    ┌─────────┐       ┌─────────┐    ┌─────────┐  ┌──────────┐
    │ Agent 1 │       │ Agent 2 │    │ Agent 3 │  │ Agent 4-6│
    │ Health  │       │Pipeline │    │  RBAC   │  │  Etc.    │
    └────┬────┘       └────┬────┘    └────┬────┘  └────┬─────┘
         │                 │              │            │
         └─────────────────┴──────────────┴────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Tool Functions Layer                      │
│  - Azure SDK wrappers (Search, Blob, Cosmos, etc.)         │
│  - Business logic (project CRUD, status checks, etc.)       │
│  - Async operations (Durable Functions integration)         │
└─────────────────────────────────────────────────────────────┘
```

## Agent 1: Project Health Monitoring Agent

### Purpose
Real-time health monitoring across all 50 projects with anomaly detection and alerting.

### Agent Configuration

```python
from agent_framework import Agent, Tool
from azure.ai.inference import ChatCompletionsClient

health_agent = Agent(
    name="ProjectHealthAgent",
    description="""You are an expert system administrator monitoring 50 EVA Jurisprudence 
    projects. Your role is to provide health status, identify issues, and recommend 
    remediation actions. Always provide specific project numbers and actionable insights.""",
    
    model=ChatCompletionsClient(
        endpoint="https://YOUR-AOAI.openai.azure.com",
        model="gpt-4o",
        api_version="2024-05-13"
    ),
    
    tools=[
        get_all_project_status,
        get_project_errors,
        get_index_statistics,
        get_queue_depths,
        check_slas,
        get_recent_alerts
    ],
    
    instructions="""
    When analyzing project health:
    1. Always check errors in Application Insights first
    2. Correlate with index statistics (document counts, sizes)
    3. Check queue depths for processing backlog
    4. Calculate SLA compliance (target: 95% docs processed <5 min)
    5. Provide specific project numbers and root causes
    6. Suggest concrete remediation steps
    
    Use emojis for status: 🟢 healthy, 🟡 warning, 🔴 critical
    """
)
```

### Tools

#### Tool 1: `get_all_project_status`

```python
@tool
async def get_all_project_status(time_range_hours: int = 24) -> dict:
    """
    Get health status for all 50 projects.
    
    Args:
        time_range_hours: Time range to analyze (default 24 hours)
    
    Returns:
        {
            "summary": {
                "healthy": 45,
                "warnings": 3,
                "critical": 2
            },
            "projects": [
                {
                    "project_num": 15,
                    "status": "critical",
                    "error_count": 23,
                    "last_error": "2026-02-08T14:30:00Z",
                    "documents_pending": 23,
                    "avg_processing_time_seconds": 180
                },
                ...
            ]
        }
    """
    # Implementation
    projects = []
    for proj_num in range(1, 51):
        # Query Application Insights
        errors = await query_app_insights(
            f"proj{proj_num}",
            time_range_hours
        )
        
        # Get index stats
        index_stats = await get_search_index_stats(f"proj{proj_num}-index")
        
        # Get queue depth
        queue_depth = await get_queue_depth_for_project(proj_num)
        
        # Calculate status
        status = "healthy"
        if errors > 10:
            status = "critical"
        elif errors > 0 or queue_depth > 50:
            status = "warning"
        
        projects.append({
            "project_num": proj_num,
            "status": status,
            "error_count": errors,
            "documents_pending": queue_depth,
            "index_doc_count": index_stats["document_count"]
        })
    
    summary = {
        "healthy": sum(1 for p in projects if p["status"] == "healthy"),
        "warnings": sum(1 for p in projects if p["status"] == "warning"),
        "critical": sum(1 for p in projects if p["status"] == "critical")
    }
    
    return {"summary": summary, "projects": projects}
```

#### Tool 2: `get_project_errors`

```python
@tool
async def get_project_errors(project_num: int, limit: int = 20) -> list:
    """
    Get recent errors for a specific project from Application Insights.
    
    Args:
        project_num: Project number (1-50)
        limit: Max number of errors to return
    
    Returns:
        List of error records with timestamp, message, and context
    """
    query = f"""
    exceptions
    | where timestamp > ago(24h)
    | where customDimensions["project_num"] == "{project_num}"
       or outerMessage contains "proj{project_num}"
    | project timestamp, type, outerMessage, operation_Name, customDimensions
    | order by timestamp desc
    | limit {limit}
    """
    
    results = await app_insights_client.query_data(query)
    
    # Parse and format errors
    errors = []
    for row in results:
        errors.append({
            "timestamp": row["timestamp"],
            "type": row["type"],
            "message": row["outerMessage"],
            "operation": row["operation_Name"],
            "context": row.get("customDimensions", {})
        })
    
    return errors
```

### Example Interaction

**User**: "Show me project health overview"

**Agent Execution**:
1. Call `get_all_project_status(24)`
2. Analyze results
3. For critical projects, call `get_project_errors(project_num)`
4. Synthesize findings

**Agent Response**:
```
Project Health Dashboard (Last 24 Hours)
=========================================

🟢 45 projects healthy
🟡 3 projects with warnings  
🔴 2 projects CRITICAL

CRITICAL ISSUES:
┌─────────┬────────────────────────────────────────────────┐
│Project 15│ 23 documents failed enrichment                │
│          │ Root cause: Azure OpenAI embedding API timeout │
│          │ Error: "TimeoutError: Request timed out"      │
│          │ Recommendation: Check AOAI endpoint health     │
└─────────┴────────────────────────────────────────────────┘
┌─────────┬────────────────────────────────────────────────┐
│Project 33│ Index storage 95% full (18.5 GB / 19.5 GB)   │
│          │ Action needed: Increase partition count OR    │
│          │ archive old documents                          │
└─────────┴────────────────────────────────────────────────┘

WARNING ISSUES:
├─ Project 7: Slow enrichment (avg 8 min vs 3 min baseline)
├─ Project 21: 12 documents in "Processing" state for >1 hour
└─ Project 42: 3 failed document uploads (invalid file format)

What would you like to investigate further?
[1] Project 15 - Embedding failures
[2] Project 33 - Index capacity
[3] View all errors across projects
[4] Set up alerts for critical issues
```

## Agent 2: Document Pipeline Orchestration Agent

### Purpose
Manage document processing lifecycle, retry operations, prioritize queues.

### Tools

```python
pipeline_agent = Agent(
    name="DocumentPipelineAgent",
    description="""Expert in EVA document processing pipeline. Track documents 
    through upload → extraction → chunking → enrichment → indexing. Handle 
    failures, retries, and prioritization.""",
    
    tools=[
        get_document_status,
        list_failed_documents,
        retry_documents,
        purge_queue,
        prioritize_project_queue,
        get_pipeline_metrics,
        reprocess_document
    ]
)
```

### Key Tool: `retry_documents`

```python
@tool
async def retry_documents(
    project_num: int,
    status_filter: str = "failed",
    date_range: str = "last-7-days"
) -> dict:
    """
    Retry processing for documents matching criteria.
    
    Args:
        project_num: Project number (1-50) or 0 for all projects
        status_filter: "failed" | "stuck" | "timeout"
        date_range: "last-24-hours" | "last-7-days" | "custom"
    
    Returns:
        {
            "queued_count": 23,
            "document_ids": [...],
            "estimated_completion_time": "2026-02-08T16:00:00Z"
        }
    """
    # 1. Query Cosmos DB for matching documents
    container_name = f"proj{project_num}-upload" if project_num >0 else None
    
    query = f"""
    SELECT * FROM c
    WHERE c.status = '{status_filter}'
      AND c.timestamp > '{get_date_range_start(date_range)}'
    """
    if container_name:
        query += f" AND c.upload_container = '{container_name}'"
    
    docs = await cosmos_client.query_items(query)
    
    # 2. For each document, re-trigger processing
    queued_count = 0
    document_ids = []
    
    for doc in docs:
        # Re-send to file-uploaded queue
        await queue_client.send_message({
            "blob_name": doc["blob_name"],
            "container": doc["upload_container"],
            "retry_attempt": doc.get("retry_count", 0) + 1
        })
        
        # Update status in Cosmos DB
        await cosmos_client.upsert_item({
            **doc,
            "status": "queued_for_retry",
            "retry_count": doc.get("retry_count", 0) + 1,
            "retry_timestamp": datetime.utcnow().isoformat()
        })
        
        queued_count += 1
        document_ids.append(doc["id"])
    
    # 3. Estimate completion time based on queue depth
    current_queue_depth = await get_total_queue_depth()
    avg_processing_rate = 50  # docs/hour (historical average)
    estimated_hours = (current_queue_depth + queued_count) / avg_processing_rate
    
    return {
        "queued_count": queued_count,
        "document_ids": document_ids,
        "estimated_completion_time": (
            datetime.utcnow() + timedelta(hours=estimated_hours)
        ).isoformat()
    }
```

## Agent 3: RBAC & Project Provisioning Agent

### Purpose
Automate project lifecycle and access management.

### Complex Workflow: Create New Project

```python
@agent_tool
async def create_new_project(
    project_num: int,
    project_name: str,
    admin_users: List[str],
    contributor_users: List[str] = None,
    reader_users: List[str] = None
) -> dict:
    """
    Fully automated project provisioning with all Azure resources and RBAC.
    
    This is a long-running operation (2-5 minutes). Returns operation ID for polling.
    """
    operation_id = str(uuid.uuid4())
    
    # Create Azure Durable Function orchestration
    orchestration_client = DurableOrchestrationClient(
        task_hub_name="EVA-Management",
        connection_string_setting="DurableFunctionsConnection"
    )
    
    instance_id = await orchestration_client.start_new(
        orchestration_function_name="ProjectProvisioningOrchestrator",
        instance_id=operation_id,
        client_input={
            "project_num": project_num,
            "project_name": project_name,
            "admin_users": admin_users,
            "contributor_users": contributor_users or [],
            "reader_users": reader_users or []
        }
    )
    
    return {
        "operation_id": operation_id,
        "status": "started",
        "estimated_duration_minutes": 3,
        "check_status_url": f"/api/operations/{operation_id}"
    }


# Durable Functions Orchestrator
async def project_provisioning_orchestrator(context: DurableOrchestrationContext):
    """
    Multi-step orchestration for project provisioning.
    Each step is idempotent and can be retried independently.
    """
    input_data = context.get_input()
    project_num = input_data["project_num"]
    project_name = input_data["project_name"]
    
    results = {}
    
    try:
        # Step 1: Validate no conflicts
        results["validation"] = await context.call_activity(
            "ValidateProjectNumber",
            project_num
        )
        
        # Step 2: Create Azure AD Groups (parallel)
        group_tasks = []
        for role in ["Admin", "Contributor", "Reader"]:
            group_tasks.append(
                context.call_activity(
                    "CreateAADGroup",
                    {"name": f"{project_name} {role}", "role": role}
                )
            )
        group_results = await asyncio.gather(*group_tasks)
        results["groups"] = {g["role"]: g for g in group_results}
        
        # Step 3: Add users to groups (parallel)
        membership_tasks = []
        for role, users in [
            ("Admin", input_data["admin_users"]),
            ("Contributor", input_data["contributor_users"]),
            ("Reader", input_data["reader_users"])
        ]:
            if users:
                membership_tasks.append(
                    context.call_activity(
                        "AddGroupMembers",
                        {"group_id": results["groups"][role]["id"], "users": users}
                    )
                )
        await asyncio.gather(*membership_tasks)
        
        # Step 4: Create storage containers (parallel)
        container_tasks = [
            context.call_activity(
                "CreateBlobContainer",
                {"name": f"proj{project_num}-upload"}
            ),
            context.call_activity(
                "CreateBlobContainer",
                {"name": f"proj{project_num}-content"}
            )
        ]
        container_results = await asyncio.gather(*container_tasks)
        results["containers"] = container_results
        
        # Step 5: Create AI Search index
        results["index"] = await context.call_activity(
            "CreateSearchIndex",
            {"name": f"proj{project_num}-index", "template": "evajp-hybrid-index"}
        )
        
        # Step 6: Assign RBAC roles (sequential for reliability)
        for role in ["Admin", "Contributor", "Reader"]:
            group_id = results["groups"][role]["id"]
            
            # Storage RBAC
            await context.call_activity(
                "AssignRBACRole",
                {
                    "scope": f"/subscriptions/{SUBSCRIPTION_ID}/resourceGroups/{RG_NAME}/providers/Microsoft.Storage/storageAccounts/{STORAGE_ACCOUNT}/blobServices/default/containers/proj{project_num}-upload",
                    "principal_id": group_id,
                    "role_definition": get_storage_role(role)
                }
            )
            
            # Search RBAC
            await context.call_activity(
                "AssignRBACRole",
                {
                    "scope": f"/subscriptions/{SUBSCRIPTION_ID}/resourceGroups/{RG_NAME}/providers/Microsoft.Search/searchServices/{SEARCH_SERVICE}/indexes/proj{project_num}-index",
                    "principal_id": group_id,
                    "role_definition": get_search_role(role)
                }
            )
        
        # Step 7: Update Cosmos DB groupmap (parallel entries)
        cosmos_tasks = []
        for role in ["Admin", "Contributor", "Reader"]:
            group = results["groups"][role]
            cosmos_tasks.append(
                context.call_activity(
                    "UpsertGroupMapItem",
                    {
                        "id": group["id"],
                        "group_id": group["id"],
                        "group_name": group["name"],
                        "upload_storage": {
                            "upload_container": f"proj{project_num}-upload",
                            "role": get_storage_role(role)
                        },
                        "blob_access": {
                            "blob_container": f"proj{project_num}-content",
                            "role_blob": get_storage_role(role)
                        },
                        "vector_index_access": {
                            "index": f"proj{project_num}-index",
                            "role_index": get_search_role(role)
                        }
                    }
                )
            )
        await asyncio.gather(*cosmos_tasks)
        
        # Step 8: Update examplelist.json config blob
        results["config"] = await context.call_activity(
            "UpdateExampleList",
            {
                "project_num": project_num,
                "project_name": project_name,
                "group_id": results["groups"]["Admin"]["id"]
            }
        )
        
        # Step 9: Notify admins
        await context.call_activity(
            "SendNotification",
            {
                "recipients": input_data["admin_users"],
                "subject": f"EVA Project {project_num} Created",
                "body": generate_welcome_email(project_num, project_name, results)
            }
        )
        
        return {
            "status": "success",
            "project_num": project_num,
            "project_name": project_name,
            "results": results,
            "duration_seconds": context.current_utc_datetime - context.start_time
        }
        
    except Exception as e:
        # Rollback logic
        await context.call_activity(
            "RollbackProject",
            {"project_num": project_num, "partial_results": results}
        )
        raise
```

### Example Interaction

**User**: "Create a new project called 'EI Claims - Atlantic Region' as project 51 with admin sarah.jones@esdc.gc.ca"

**Agent**:
```
✅ Starting project provisioning for Project 51: "EI Claims - Atlantic Region"

Progress:
[████████████████████░░░░] 85% Complete

✓ Azure AD Groups created (3)
✓ Users added to groups
✓ Storage containers created (proj51-upload, proj51-content)
✓ AI Search index created (proj51-index)
✓ RBAC roles assigned (12 role assignments)
✓ Cosmos DB groupmap updated
✓ Configuration updated

⏳ Finalizing... (sending notifications)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Project 51 provisioned successfully!

Details:
- Project Name: EI Claims - Atlantic Region
- Project Number: 51
- Admin: sarah.jones@esdc.gc.ca
- Upload Container: proj51-upload
- Content Container: proj51-content
- Search Index: proj51-index

Next Steps:
1. Admin will receive welcome email with instructions
2. Upload first documents to test
3. Verify access at https://eva-jp.esdc.gc.ca (refresh to see new project)

Total Time: 2 minutes 34 seconds
```

---

## Multi-Agent Coordination

### Scenario: Complex Investigation

**User**: "Project 15 has been slow today, investigate why"

**Orchestrator**:
1. Routes to Health Agent (primary)
2. Health Agent calls `get_project_errors(15)`
3. Finds embedding API timeouts
4. Collaborates with Pipeline Agent to check queue
5. Collaborates with Diagnostic Agent for root cause

**Agent Conversation** (internal):
```
HealthAgent → PipelineAgent: "Check queue depth for project 15"
PipelineAgent → HealthAgent: "Queue depth: 23 messages, oldest 2 hours"

HealthAgent → DiagnosticAgent: "Analyze embedding API errors for project 15"
DiagnosticAgent → HealthAgent: "Pattern detected: 429 Rate Limit errors from 
                              Azure OpenAI, started at 14:00 UTC. Likely hitting
                              tokens-per-minute quota."

HealthAgent → User: [synthesized response]
```

---

## Deployment Architecture

### Infrastructure as Code

```hcl
# Terraform for Agent App Service
resource "azurerm_app_service" "management_agents" {
  name                = "eva-management-agents"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.plan.id
  
  app_settings = {
    "AZURE_OPENAI_ENDPOINT" = var.openai_endpoint
    "AZURE_OPENAI_MODEL" = "gpt-4o"
    "COSMOS_DB_ENDPOINT" = var.cosmos_endpoint
    "AI_SEARCH_ENDPOINT" = var.search_endpoint
    "APP_INSIGHTS_CONNECTION_STRING" = var.app_insights_connection
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  site_config {
    linux_fx_version = "PYTHON|3.11"
    always_on = true
  }
}

# Grant Managed Identity permissions
resource "azurerm_role_assignment" "agents_cosmos_reader" {
  scope                = var.cosmos_db_id
  role_definition_name = "Cosmos DB Account Reader Role"
  principal_id         = azurerm_app_service.management_agents.identity[0].principal_id
}

resource "azurerm_role_assignment" "agents_search_admin" {
  scope                = var.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_app_service.management_agents.identity[0].principal_id
}

# APIM API
resource "azurerm_api_management_api" "agents" {
  name                = "management-agents"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = var.apim_name
  revision            = "1"
  display_name        = "EVA Management Agents API"
  path                = "manage"
  protocols           = ["https"]
  
  service_url = "https://eva-management-agents.azurewebsites.net"
}
```

---

**Next Document**: [Cost-Benefit Analysis](./cost-benefit-analysis.md)
