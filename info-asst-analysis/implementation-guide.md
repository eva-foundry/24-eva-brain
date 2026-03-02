# Implementation Guide

## Quick Start

This guide helps you begin implementing management agents for EVA JP 1.2.

## Prerequisites

### Development Environment

1. **Python 3.11+**
2. **VS Code** with extensions:
   - Python
   - Azure Tools
   - AI Toolkit (for Agent Inspector)
3. **Azure CLI** (authenticated to EsPAICOESub or EsDAICoE-Sandbox)
4. **Git** (access to EVA JP 1.2 repository)

### Azure Resources Access

Ensure you have access to:
- Azure OpenAI (gpt-4o model deployed)
- Cosmos DB (readonly access minimum)
- Azure AI Search (readonly for monitoring)
- Application Insights (reader role)
- Azure Cost Management API (reader)

## Phase 1: Prototype Agent 1 (Project Health)

### Step 1: Set Up Development Environment

```bash
# Clone repository
cd C:\AICOE\eva-foundation\24-eva-brain
mkdir agent-prototype
cd agent-prototype

# Create Python virtual environment
python -m venv .venv
.\.venv\Scripts\activate  # Windows
# source .venv/bin/activate  # Linux/Mac

# Install dependencies
pip install agent-framework-azure-ai==1.0.0b260107
pip install agent-framework-core==1.0.0b260107
pip install azure-ai-inference
pip install azure-cosmos
pip install azure-search-documents
pip install azure-monitor-query
pip install azure-identity
pip install fastapi
pip install uvicorn[standard]
pip install python-dotenv
```

### Step 2: Configure Environment Variables

Create `.env` file:

```bash
# Azure OpenAI
AZURE_OPENAI_ENDPOINT=https://YOUR-OPENAI.openai.azure.com
AZURE_OPENAI_MODEL=gpt-4o
AZURE_OPENAI_API_VERSION=2024-05-13

# Cosmos DB (from EVA JP 1.2 deployment)
COSMOS_DB_ENDPOINT=https://YOUR-COSMOS.documents.azure.com:443/
COSMOS_DB_DATABASE=YOUR-DB-NAME
COSMOS_DB_GROUPMAP_CONTAINER=groupResourcesMapContainer
COSMOS_DB_STATUSLOG_CONTAINER=statusLogs

# Azure AI Search (from EVA JP 1.2 deployment)
AI_SEARCH_ENDPOINT=https://YOUR-SEARCH.search.windows.net
AI_SEARCH_API_VERSION=2023-11-01

# Application Insights
APP_INSIGHTS_WORKSPACE_ID=YOUR-WORKSPACE-ID
APP_INSIGHTS_CONNECTION_STRING=YOUR-CONNECTION-STRING

# Authentication
AZURE_TENANT_ID=YOUR-TENANT-ID
AZURE_CLIENT_ID=YOUR-CLIENT-ID  # If using service principal
AZURE_CLIENT_SECRET=YOUR-SECRET  # If using service principal
# Or use DefaultAzureCredential (recommended for local dev)

# Agent Configuration
AGENT_LOG_LEVEL=DEBUG
AGENT_ENABLE_TRACING=true
```

### Step 3: Create Agent Tools

File: `tools/project_health.py`

```python
"""
Project Health Monitoring Tools
"""
import os
from typing import Dict, List
from datetime import datetime, timedelta
from azure.identity import DefaultAzureCredential
from azure.cosmos import CosmosClient
from azure.monitor.query import LogsQueryClient, LogsQueryStatus
from azure.search.documents import SearchClient
from azure.core.exceptions import ResourceNotFoundError

# Initialize Azure clients
credential = DefaultAzureCredential()

cosmos_client = CosmosClient(
    url=os.getenv("COSMOS_DB_ENDPOINT"),
    credential=credential
)

logs_client = LogsQueryClient(credential=credential)

def get_search_client(index_name: str) -> SearchClient:
    """Get search client for specificindex"""
    return SearchClient(
        endpoint=os.getenv("AI_SEARCH_ENDPOINT"),
        index_name=index_name,
        credential=credential
    )


async def get_all_project_status(time_range_hours: int = 24) -> Dict:
    """
    Get health status for all 50 projects.
    
    Args:
        time_range_hours: Time range to analyze
    
    Returns:
        Dictionary with summary and per-project details
    """
    projects = []
    
    # Query Cosmos DB for groupmap to get all projects
    database = cosmos_client.get_database_client(os.getenv("COSMOS_DB_DATABASE"))
    container = database.get_container_client(os.getenv("COSMOS_DB_GROUPMAP_CONTAINER"))
    
    # Get all unique project numbers from groupmap
    query = "SELECT DISTINCT VALUE SUBSTRING(c.upload_storage.upload_container, 4, 2) FROM c"
    project_nums = set()
    for item in container.query_items(query=query, enable_cross_partition_query=True):
        try:
            project_nums.add(int(item))
        except:
            pass
    
    # For each project, gather health metrics
    for proj_num in sorted(project_nums):
        project_status = await analyze_project_health(proj_num, time_range_hours)
        projects.append(project_status)
    
    # Calculate summary
    summary = {
        "total": len(projects),
        "healthy": sum(1 for p in projects if p["status"] == "healthy"),
        "warnings": sum(1 for p in projects if p["status"] == "warning"),
        "critical": sum(1 for p in projects if p["status"] == "critical"),
        "offline": sum(1 for p in projects if p["status"] == "offline")
    }
    
    return {
        "summary": summary,
        "timestamp": datetime.utcnow().isoformat(),
        "time_range_hours": time_range_hours,
        "projects": projects
    }


async def analyze_project_health(proj_num: int, time_range_hours: int) -> Dict:
    """
    Analyze health for a single project.
    """
    index_name = f"proj{proj_num}-index"
    
    # Get error count from Application Insights
    workspace_id = os.getenv("APP_INSIGHTS_WORKSPACE_ID")
    start_time = datetime.utcnow() - timedelta(hours=time_range_hours)
    
    kusto_query = f"""
    exceptions
    | where timestamp > datetime({start_time.isoformat()})
    | where outerMessage contains "proj{proj_num}" or customDimensions.project_num == "{proj_num}"
    | summarize error_count=count() by bin(timestamp, 1h)
    """
    
    try:
        response = logs_client.query_workspace(
            workspace_id=workspace_id,
            query=kusto_query,
            timespan=timedelta(hours=time_range_hours)
        )
        
        error_count = 0
        if response.status == LogsQueryStatus.SUCCESS:
            tables = response.tables
            if tables:
                for row in tables[0].rows:
                    error_count += row[1]  # error_count column
    except Exception as e:
        print(f"Error querying App Insights for project {proj_num}: {e}")
        error_count = 0
    
    # Get index statistics
    try:
        search_client = get_search_client(index_name)
        # Get document count via search
        results = search_client.search(search_text="*", include_total_count=True, top=0)
        doc_count = results.get_count()
        index_exists = True
    except ResourceNotFoundError:
        doc_count = 0
        index_exists = False
    except Exception as e:
        print(f"Error querying search index for project {proj_num}: {e}")
        doc_count = 0
        index_exists = False
    
    # Get queue depth (pending documents)
    # Query Cosmos DB status logs for Processing status
    database = cosmos_client.get_database_client(os.getenv("COSMOS_DB_DATABASE"))
    statuslog_container = database.get_container_client(os.getenv("COSMOS_DB_STATUSLOG_CONTAINER"))
    
    pending_query = f"""
    SELECT VALUE COUNT(1) FROM c 
    WHERE c.status = 'Processing' 
      AND c.upload_container = 'proj{proj_num}-upload'
    """
    
    try:
        pending_results = list(statuslog_container.query_items(
            query=pending_query,
            enable_cross_partition_query=True
        ))
        pending_count = pending_results[0] if pending_results else 0
    except Exception as e:
        print(f"Error querying pending docs for project {proj_num}: {e}")
        pending_count = 0
    
    # Determine health status
    if not index_exists:
        status = "offline"
    elif error_count > 10:
        status = "critical"
    elif error_count > 0 or pending_count > 50:
        status = "warning"
    else:
        status = "healthy"
    
    return {
        "project_num": proj_num,
        "index_name": index_name,
        "status": status,
        "metrics": {
            "error_count": error_count,
            "document_count": doc_count,
            "pending_count": pending_count,
            "index_exists": index_exists
        }
    }


async def get_project_errors(proj_num: int, limit: int = 20) -> List[Dict]:
    """
    Get recent errors for specific project.
    """
    workspace_id = os.getenv("APP_INSIGHTS_WORKSPACE_ID")
    
    kusto_query = f"""
    exceptions
    | where timestamp > ago(24h)
    | where outerMessage contains "proj{proj_num}" or customDimensions.project_num == "{proj_num}"
    | project timestamp, type, outerMessage, operation_Name, customDimensions
    | order by timestamp desc
    | limit {limit}
    """
    
    try:
        response = logs_client.query_workspace(
            workspace_id=workspace_id,
            query=kusto_query,
            timespan=timedelta(hours=24)
        )
        
        errors = []
        if response.status == LogsQueryStatus.SUCCESS and response.tables:
            table = response.tables[0]
            for row in table.rows:
                errors.append({
                    "timestamp": row[0],
                    "type": row[1],
                    "message": row[2],
                    "operation": row[3],
                    "context": row[4] if len(row) > 4 else {}
                })
        
        return errors
    except Exception as e:
        print(f"Error fetching errors for project {proj_num}: {e}")
        return []
```

### Step 4: Create Health Agent

File: `agents/health_agent.py`

```python
"""
Project Health Monitoring Agent
"""
import os
import sys
from typing import Any
from agent_framework.openai import OpenAIChatClient
from agent_framework import as_agent

# Add tools directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from tools.project_health import get_all_project_status, get_project_errors


# Create agent client
client = OpenAIChatClient(
    model=os.getenv("AZURE_OPENAI_MODEL"),
    endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_version=os.getenv("AZURE_OPENAI_API_VERSION")
)


# Define agent with system prompt
@as_agent(
    client=client,
    tools=[get_all_project_status, get_project_errors],
    name="ProjectHealthAgent"
)
async def health_agent(user_message: str) -> str:
    """
    You are an expert system administrator monitoring 50 EVA Jurisprudence projects.
    Your role is to provide health status, identify issues, and recommend remediation.
    
    Guidelines:
    - Always provide specific project numbers
    - Use emojis for status: 🟢 healthy, 🟡 warning, 🔴 critical
    - Prioritize critical issues
    - Suggest concrete, actionable remediation steps
    - Reference Azure services by name (Application Insights, AI Search, etc.)
    
    When analyzing project health:
    1. Check error counts in Application Insights
    2. Verify index statistics (document counts, availability)
    3. Check pending document counts
    4. Calculate SLA compliance (target: 95% docs processed <5 min)
    5. Provide root cause analysis when errors detected
    """
    return user_message


# CLI for testing
if __name__ == "__main__":
    import asyncio
    from dotenv import load_dotenv
    
    load_dotenv()
    
    async def main():
        print("=== Project Health Agent (Test Mode) ===\n")
        
        # Test queries
        test_queries = [
            "Show me project health overview",
            "What errors does project 15 have?",
            "Which projects are critical?"
        ]
        
        for query in test_queries:
            print(f"\n🔹 User: {query}")
            response = await health_agent(query)
            print(f"🤖 Agent: {response}\n")
            print("-" * 80)
    
    asyncio.run(main())
```

### Step 5: Test the Agent

```bash
# Run the test
python agents/health_agent.py
```

Expected output:
```
=== Project Health Agent (Test Mode) ===

🔹 User: Show me project health overview
🤖 Agent: Let me check the health status across all projects...

[Agent calls get_all_project_status tool]

Project Health Dashboard (Last 24 Hours)
=========================================

🟢 45 projects healthy
🟡 3 projects with warnings
🔴 2 projects CRITICAL

CRITICAL ISSUES:
...
```

### Step 6: Add Debugging with Agent Inspector

1. **Open VS Code**
2. **Install AI Toolkit extension** (if not already)
3. **Add debugging configuration**:

File: `.vscode/launch.json`

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Health Agent",
      "type": "python",
      "request": "launch",
      "module": "agents.health_agent",
      "console": "integratedTerminal",
      "justMyCode": false,
      "env": {
        "PYTHONPATH": "${workspaceFolder}",
        "AGENT_ENABLE_TRACING": "true"
      }
    }
  ]
}
```

4. **Set breakpoints** in `agents/health_agent.py`
5. **Press F5** to start debugging
6. **Open Agent Inspector** (AI Toolkit extension sidebar)

You'll see:
- Agent reasoning process (LLM thoughts)
- Tool calls with parameters
- Tool responses
- Final agent response

### Step 7: Wrap in FastAPI Service

File: `api/main.py`

```python
"""
Management Agents API Service
"""
import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
import sys

load_dotenv()

# Add agents to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from agents.health_agent import health_agent

app = FastAPI(
    title="EVA Management Agents API",
    description="AI-powered management for EVA JP 1.2 multi-tenant infrastructure",
    version="0.1.0"
)


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    response: str
    agent: str = "ProjectHealthAgent"


@app.post("/chat/health", response_model=ChatResponse)
async def chat_health(request: ChatRequest):
    """
    Chat with Project Health Monitoring Agent
    """
    try:
        response = await health_agent(request.message)
        return ChatResponse(response=response)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    """API health check"""
    return {"status": "healthy", "service": "eva-management-agents"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

Test the API:

```bash
# Start the service
python api/main.py

# In another terminal, test with curl
curl -X POST http://localhost:8000/chat/health \
  -H "Content-Type: application/json" \
  -d '{"message": "Show me project health overview"}'
```

## Phase 2: Deploy to Azure

### Step 1: Create App Service

```bash
# Variables
RG_NAME="EsDAICoE-Sandbox"
APP_NAME="eva-management-agents-dev"
PLAN_NAME="eva-agents-plan"
LOCATION="canadacentral"

# Create App Service Plan (Linux, Python 3.11)
az appservice plan create \
  --name $PLAN_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --is-linux \
  --sku B1

# Create App Service
az webapp create \
  --name $APP_NAME \
  --resource-group $RG_NAME \
  --plan $PLAN_NAME \
  --runtime "PYTHON:3.11"

# Enable Managed Identity
az webapp identity assign \
  --name $APP_NAME \
  --resource-group $RG_NAME

# Configure environment variables
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RG_NAME \
  --settings \
    AZURE_OPENAI_ENDPOINT="https://YOUR-OPENAI.openai.azure.com" \
    AZURE_OPENAI_MODEL="gpt-4o" \
    COSMOS_DB_ENDPOINT="https://YOUR-COSMOS.documents.azure.com:443/" \
    AI_SEARCH_ENDPOINT="https://YOUR-SEARCH.search.windows.net" \
    APP_INSIGHTS_WORKSPACE_ID="YOUR-WORKSPACE-ID"
```

### Step 2: Grant RBAC Permissions

```bash
# Get App Service Managed Identity
PRINCIPAL_ID=$(az webapp identity show \
  --name $APP_NAME \
  --resource-group $RG_NAME \
  --query principalId -o tsv)

# Grant Cosmos DB reader role
az cosmosdb sql role assignment create \
  --account-name YOUR-COSMOS-ACCOUNT \
  --resource-group $RG_NAME \
  --role-definition-name "Cosmos DB Account Reader Role" \
  --principal-id $PRINCIPAL_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.DocumentDB/databaseAccounts/YOUR-COSMOS-ACCOUNT"

# Grant AI Search reader role
az role assignment create \
  --role "Search Index Data Reader" \
  --assignee $PRINCIPAL_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Search/searchServices/YOUR-SEARCH-SERVICE"

# Grant Application Insights reader role
az role assignment create \
  --role "Monitoring Reader" \
  --assignee $PRINCIPAL_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/microsoft.insights/components/YOUR-APP-INSIGHTS"
```

### Step 3: Deploy Code

```bash
# Create deployment package
cd agent-prototype
zip -r deployment.zip . -x "*.git*" -x "*__pycache__*" -x "*.venv*"

# Deploy to App Service
az webapp deployment source config-zip \
  --name $APP_NAME \
  --resource-group $RG_NAME \
  --src deployment.zip

# Set startup command
az webapp config set \
  --name $APP_NAME \
  --resource-group $RG_NAME \
  --startup-file "python -m uvicorn api.main:app --host 0.0.0.0 --port 8000"

# Restart app
az webapp restart --name $APP_NAME --resource-group $RG_NAME
```

### Step 4: Test Deployed Service

```bash
# Get App Service URL
APP_URL=$(az webapp show \
  --name $APP_NAME \
  --resource-group $RG_NAME \
  --query defaultHostName -o tsv)

# Test health endpoint
curl https://$APP_URL/health

# Test agent (requires authentication if enabled)
curl -X POST https://$APP_URL/chat/health \
  -H "Content-Type: application/json" \
  -d '{"message": "Show me project health overview"}'
```

## Integration with APIM

### Step 1: Import API to APIM

```bash
APIM_NAME="eva-apim-dev"

# Import OpenAPI spec
az apim api import \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --path "manage/health" \
  --specification-url "https://$APP_URL/openapi.json" \
  --specification-format OpenApi \
  --api-id "management-agents-health"
```

### Step 2: Add Authentication Policy

In Azure Portal > APIM > APIs > management-agents-health > Policies:

```xml
<policies>
  <inbound>
    <base />
    <!-- Validate Azure AD JWT token -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
      <openid-config url="https://login.microsoftonline.com/YOUR-TENANT-ID/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>api://eva-management-agents</audience>
      </audiences>
    </validate-jwt>
    
    <!-- Rate limiting -->
    <rate-limit calls="100" renewal-period="60" />
    
    <!-- Logging -->
    <log-to-eventhub logger-id="apim-logger">
      @{
        return new {
          Timestamp = DateTime.UtcNow,
          ApiId = context.Api.Id,
          Operation = context.Operation.Id,
          UserId = context.User?.Id,
          Request = context.Request.Body.As<string>(preserveContent: true)
        };
      }
    </log-to-eventhub>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
```

## Testing Checklist

- [ ] Agent responds to health check queries
- [ ] Agent correctly identifies critical projects
- [ ] Agent provides actionable recommendations
- [ ] All Azure SDK tools work with Managed Identity
- [ ] Agent tracing works in Agent Inspector
- [ ] API deployment successful
- [ ] APIM authentication working
- [ ] Rate limiting configured
- [ ] Monitoring/logging enabled

## Troubleshooting

### Issue: Agent not calling tools

**Solution**: Check tool definitions match expected schema:

```python
# Tool must be async and properly typed
async def get_all_project_status(time_range_hours: int = 24) -> Dict:
    """
    Docstring is important! Agent uses this to understand when to call tool.
    
    Args:
        time_range_hours: Clear parameter descriptions help LLM
    
    Returns:
        Clear return type description
    """
    pass
```

### Issue: Azure authentication failures

**Solution**: Verify Managed Identity has correct roles:

```bash
# List role assignments
az role assignment list \
  --assignee $PRINCIPAL_ID \
  --output table
```

### Issue: Slow agent response

**Solution**: Check:
1. LLM token usage (verbose prompts = slow)
2. Tool execution time (add logging)
3. Network latency to Azure services

---

## Next Steps

1. ✅ Prototype Agent 1 (Health) working locally
2. ✅ Deploy to Azure App Service
3. ✅ Integrate with APIM
4. ⏭️ [Implement Agent 2 (Pipeline)](./agent-2-pipeline.md)
5. ⏭️ [Implement Agent 3 (RBAC)](./agent-3-rbac.md)

## Resources

- [Microsoft Agent Framework Docs](https://github.com/microsoft/agent-framework)
- [Azure AI Toolkit](https://marketplace.visualstudio.com/items?itemName=ms-windows-ai-studio.windows-ai-studio)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-services/openai/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

---

**Last Updated**: February 8, 2026  
**Author**: GitHub Copilot (Agent Mode)
