# RBAC Multi-Tenancy Deep Dive

## Architecture Pattern: Duplicative Multi-Tenancy

EVA JP 1.2 implements **resource duplication per tenant** rather than logical tenancy.

### Resource Duplication Model

```
┌──────────────────────────────────────────────────────────────┐
│                     Single Storage Account                    │
│                                                               │
│  ┌──────────────┐ ┌──────────────┐     ┌──────────────┐    │
│  │ proj1-upload │ │ proj1-content│ ... │ proj50-upload│    │
│  └──────────────┘ └──────────────┘     └──────────────┘    │
│                                                               │
│  Total: 100 containers (50 upload + 50 content)             │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                    Single AI Search Service                   │
│                                                               │
│  ┌──────────────┐ ┌──────────────┐     ┌──────────────┐    │
│  │  proj1-index │ │  proj2-index │ ... │ proj50-index │    │
│  └──────────────┘ └──────────────┘     └──────────────┘    │
│                                                               │
│  Total: 50 indexes with identical schema                    │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                      Cosmos DB Database                       │
│                                                               │
│  Container: groupResourcesMapContainer                       │
│  Documents: 150 (50 projects × 3 roles each)                │
│                                                               │
│  {                                                            │
│    "group_id": "abc-123",                                    │
│    "group_name": "AICoE Playground Project 15 Admin",       │
│    "upload_storage": {                                       │
│      "upload_container": "proj15-upload",                    │
│      "role": "Storage Blob Data Owner"                       │
│    },                                                        │
│    "blob_access": {                                          │
│      "blob_container": "proj15-content",                     │
│      "role_blob": "Storage Blob Data Owner"                  │
│    },                                                        │
│    "vector_index_access": {                                  │
│      "index": "proj15-index",                                │
│      "role_index": "Search Index Data Contributor"           │
│    }                                                         │
│  }                                                           │
└──────────────────────────────────────────────────────────────┘
```

## Code Analysis: RBAC Resolution

### Entry Point: Backend Request Handler

From `app/backend/app.py`:

```python
# Caching layer for groupmap (reduces Cosmos DB queries)
group_items, expired_time = 0, 0

@asynccontextmanager
async def lifespan(app: FastAPI):
    global group_items, expired_time
    
    # Initialize Cosmos DB clients
    groupmapcontainer = initiate_group_resource_map(AZURE_CREDENTIAL, cosmos_client=cosmosdb_client)
    
    # Load and cache all group mappings
    group_items, expired_time = read_all_items_into_cache_if_expired(groupmapcontainer)
    
    # Pre-populate container and index client maps
    upload_containers = read_all_upload_containers(group_items)
    content_containers = read_all_content_containers(group_items)
    vector_indexes = read_all_vector_indexes(group_items)
    
    # Create 100 blob container clients
    for content_container in content_containers:
        content_container_to_content_blob_container_client_map[content_container] = \
            app_clients[AZURE_BLOB_CLIENT_KEY].get_container_client(content_container)
    
    for upload_container in upload_containers:
        upload_container_to_upload_blob_container_client_map[upload_container] = \
            app_clients[AZURE_BLOB_CLIENT_KEY].get_container_client(upload_container)
    
    # Create 50 search clients
    for index in vector_indexes:
        index_to_search_client_map[index] = SearchClient(
            endpoint=ENV["AZURE_SEARCH_SERVICE_ENDPOINT"], 
            index_name=index, 
            credential=AZURE_CREDENTIAL, 
            audience=ENV["AZURE_SEARCH_AUDIENCE"]
        )
```

**Key Observation**: Startup pre-initializes 150 client objects (100 blob + 50 search)

### RBAC Resolution Functions

From `functions/shared_code/utility_rbck.py`:

#### 1. Decode Authentication Token

```python
def decode_x_ms_client_principal(request):
    """
    Decode Azure AD EasyAuth token from header.
    Returns: {
        "claims": [
            {"typ": "groups", "val": "group-id-1"},
            {"typ": "groups", "val": "group-id-2"},
            ...
        ],
        "name_typ": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
        "role_typ": "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
    }
    """
    x_ms_client_principal = request.headers.get("x-ms-client-principal")
    if not x_ms_client_principal:
        return None
    
    decoded = base64.b64decode(x_ms_client_principal)
    client_principal = json.loads(decoded)
    return client_principal
```

#### 2. Find Controlling Group

```python
def find_grpid_ctrling_rbac(request, group_map_items):
    """
    Determine which group controls RBAC for this user.
    Priority: Admin > Contributor > Reader
    
    Returns: group_id (str) or None
    """
    try:
        client_principal_payload = decode_x_ms_client_principal(request)
        
        # Extract all group IDs from user's token
        user_groups = [principal["val"] for principal in client_principal_payload["claims"]]
        
        # Get all group IDs that have project mappings
        groups_ids_in_group_map = [item.get("group_id") for item in group_map_items]
        
        # Find intersection (groups user belongs to that have resource mappings)
        rbac_group_l = list(set(user_groups).intersection(set(groups_ids_in_group_map)))
        
        if len(rbac_group_l) > 0:
            # Build role mapping with priority
            role_mapping = {}
            for grp_id in rbac_group_l:
                for item in group_map_items:
                    if item.get("group_id") == grp_id:
                        grp_name = item.get("group_name")
                        
                        # Classify by role name
                        if "admin" in grp_name.lower():
                            if "admin" not in role_mapping:
                                role_mapping["admin"] = {grp_name: grp_id}
                            else:
                                role_mapping["admin"][grp_name] = grp_id
                        elif "contributor" in grp_name.lower():
                            if "contributor" not in role_mapping:
                                role_mapping["contributor"] = {grp_name: grp_id}
                            else:
                                role_mapping["contributor"][grp_name] = grp_id
                        elif "reader" in grp_name.lower():
                            if "reader" not in role_mapping:
                                role_mapping["reader"] = {grp_name: grp_id}
                            else:
                                role_mapping["reader"][grp_name] = grp_id
                        break
            
            # Return highest priority group
            if "admin" in role_mapping:
                grp_name, grp_id = sorted(role_mapping["admin"].items())[0]
                return grp_id
            if "contributor" in role_mapping:
                grp_name, grp_id = sorted(role_mapping["contributor"].items())[0]
                return grp_id
            if "reader" in role_mapping:
                grp_name, grp_id = sorted(role_mapping["reader"].items())[0]
                return grp_id
        else:
            return None
    except Exception as e:
        logger.error(f"An error occurred: {e}")
        return None
```

**Key Logic**: 
- Extract user's AAD group memberships
- Find overlap with project group mappings
- Prioritize: Admin > Contributor > Reader
- Return single group ID

#### 3. Resolve Resources

```python
def find_upload_container_and_role(request, group_map_items, current_grp_id=None):
    """Get upload container and role for user's controlling group"""
    if not current_grp_id:
        current_grp_id = find_grpid_ctrling_rbac(request, group_map_items)
        if not current_grp_id:
            return None, None
    
    for item in group_map_items:
        if item.get("group_id") == current_grp_id:
            container_and_role = item.get("upload_storage")
            blob_container = container_and_role.get("upload_container")  # e.g., "proj15-upload"
            role = container_and_role.get("role")                        # e.g., "Storage Blob Data Owner"
            return blob_container, role
    return None, None

def find_container_and_role(request, group_map_items, current_grp_id=None):
    """Get content container and role for user's controlling group"""
    if not current_grp_id:
        current_grp_id = find_grpid_ctrling_rbac(request, group_map_items)
        if not current_grp_id:
            return None, None
    
    for item in group_map_items:
        if item.get("group_id") == current_grp_id:
            container_and_role = item.get("blob_access")
            blob_container = container_and_role.get("blob_container")   # e.g., "proj15-content"
            role = container_and_role.get("role_blob")
            return blob_container, role
    return None, None

def find_index_and_role(request, group_map_items, current_grp_id=None):
    """Get search index and role for user's controlling group"""
    if not current_grp_id:
        current_grp_id = find_grpid_ctrling_rbac(request, group_map_items)
        if not current_grp_id:
            return None, None
    
    for item in group_map_items:
        if item.get("group_id") == current_grp_id:
            index_and_role = item.get("vector_index_access")
            vector_index = index_and_role.get("index")                   # e.g., "proj15-index"
            role = index_and_role.get("role_index")
            return vector_index, role
    return None, None
```

### Usage in API Endpoints

Example: Document Upload Endpoint

```python
@app.post("/upload")
async def upload_document(request: Request, file: UploadFile):
    # 1. Resolve user's group and resources
    upload_container, role = find_upload_container_and_role(request, group_items)
    
    if not upload_container:
        raise HTTPException(status_code=403, detail="No upload access")
    
    # 2. Get pre-initialized blob client for this container
    blob_client = upload_container_to_upload_blob_container_client_map[upload_container]
    
    # 3. Upload file to user's project-specific container
    blob_name = f"{user_oid}/{file.filename}"
    await blob_client.upload_blob(name=blob_name, data=file.file)
    
    # 4. Trigger processing pipeline (queue message with container metadata)
    await queue_client.send_message({
        "blob_name": blob_name,
        "container": upload_container,
        "user_oid": user_oid
    })
    
    return {"status": "uploaded", "container": upload_container}
```

Example: Chat/Search Endpoint

```python
@app.post("/chat")
async def chat(request: Request, query: str):
    # 1. Resolve user's search index
    index_name, role = find_index_and_role(request, group_items)
    
    if not index_name:
        raise HTTPException(status_code=403, detail="No search access")
    
    # 2. Get pre-initialized search client for this index
    search_client = index_to_search_client_map[index_name]
    
    # 3. Execute search against user's project-specific index
    results = search_client.search(
        search_text=query,
        vector_queries=[...],
        top=10
    )
    
    # 4. Generate response with RAG
    context = [doc["content"] for doc in results]
    response = await openai_client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "Answer based on context"},
            {"role": "user", "content": f"Context: {context}\n\nQuestion: {query}"}
        ]
    )
    
    return {"answer": response.choices[0].message.content, "index": index_name}
```

## Enrichment Pipeline with RBAC

### Flow Diagram

```
┌─────────────────┐
│  User Uploads   │
│  Document to    │
│  proj15-upload  │
└────────┬────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  FileUploadedTrigger (Azure Function)│
│  - Detects new blob in proj15-upload │
│  - Reads upload container name        │
│  - Queues message with metadata       │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  file-uploaded Queue                 │
│  Message: {                          │
│    "blob_name": "doc.pdf",           │
│    "container": "proj15-upload",     │
│    "timestamp": "..."                │
│  }                                   │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  FileFormRecSubmission               │
│  - Lookup: proj15-upload → groupmap  │
│  - Find: proj15-content container    │
│  - Submit to Document Intelligence   │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  text-enrichment Queue               │
│  Message: {                          │
│    "chunks": [...],                  │
│    "upload_container": "proj15-upload",│
│    "metadata": {...}                 │
│  }                                   │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  Enrichment Service (App Service)    │
│  1. Dequeue message                  │
│  2. Lookup upload_container groupmap │
│  3. Resolve: proj15-index            │
│  4. Generate embeddings (OpenAI)     │
│  5. Upload chunks to proj15-index    │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  AI Search: proj15-index             │
│  - Document now searchable           │
│  - Only accessible to proj15 users   │
└──────────────────────────────────────┘
```

### Key Code: Enrichment Service

From `app/enrichment/app.py`:

```python
async def process_embeddings_message(message):
    """Process a single embeddings queue message"""
    
    # 1. Parse message
    data = json.loads(message.content)
    upload_container = data["upload_container"]
    chunks = data["chunks"]
    
    # 2. Resolve target index from upload container
    content_container, role = find_content_container_and_role_based_on_upcontainer(
        upload_container, group_items
    )
    index_name, role_index = find_index_and_role_based_on_upcontainer(
        upload_container, group_items
    )
    
    if not index_name:
        log.error(f"Cannot resolve index for upload container: {upload_container}")
        return
    
    # 3. Generate embeddings
    embeddings = []
    for chunk in chunks:
        embedding = await openai_client.embeddings.create(
            model="text-embedding-ada-002",
            input=chunk["text"]
        )
        embeddings.append(embedding.data[0].embedding)
    
    # 4. Upload to target index
    search_client = SearchClient(
        endpoint=ENV["AZURE_SEARCH_SERVICE_ENDPOINT"],
        index_name=index_name,
        credential=AZURE_CREDENTIAL
    )
    
    documents = []
    for i, chunk in enumerate(chunks):
        documents.append({
            "id": chunk["id"],
            "content": chunk["text"],
            "content_vector": embeddings[i],
            "source_container": content_container,
            "metadata": chunk["metadata"]
        })
    
    result = search_client.upload_documents(documents)
    log.info(f"Uploaded {len(documents)} chunks to {index_name}")
```

## Management Challenges with Current Architecture

### Challenge 1: No Cross-Project Visibility

**Scenario**: "Are any projects experiencing enrichment delays?"

**Current Process**:
1. Open Azure Portal
2. Navigate to AI Search service
3. Manually check each of 50 indexes for document count changes
4. Compare with Cosmos DB upload logs
5. Check Application Insights for errors
6. **Time**: 30-60 minutes

**With Management Agent**:
```
User: "Show me enrichment status across all projects"

Agent Response:
Enrichment Status (Last 1 Hour)
================================
✅ 45 projects: Normal (<3 min avg)
⚠️  3 projects: Slow (5-8 min avg)
🔴 2 projects: Stalled (>1 hour)

STALLED:
- Project 15: 23 docs pending (queue depth: 23, last processed: 2h ago)
- Project 33: 8 docs pending (queue depth: 8, last processed: 90m ago)

Cause: Azure OpenAI embedding API throttling (429 errors)
Recommendation: Increase quota or enable retry backoff
```

**Time**: 2 seconds

### Challenge 2: RBAC Group Sprawl

**Current State**:
- 150 Azure AD security groups
- Manual naming convention enforcement
- No automated synchronization with Cosmos groupmap
- Risk of drift between AAD and groupmap

**Future State with Agent**:
- Agent validates group naming on creation
- Detects and reports drift (weekly audit)
- Suggests consolidation opportunities
- Automates group lifecycle (create, update, archive)

### Challenge 3: Cost Attribution

**Current State**:
- No per-project cost tracking
- Cannot identify high-cost projects
- No chargeback mechanism
- Difficult to justify budget requests

**With Cost Agent**:
```
User: "Which projects are costing the most this month?"

Agent Response:
Top 10 Projects by Cost (January 2026)
=======================================
1. Project 12: $425 (4,200 docs, 8,500 queries)
2. Project 3:  $380 (3,800 docs, 7,200 queries)
3. Project 7:  $310 (2,900 docs, 5,100 queries)
...

Cost Breakdown for Project 12:
- AI Search Index: $180 (S2 tier, 4200 docs)
- Blob Storage:    $95 (hot tier, 850 GB)
- Azure OpenAI:    $120 (embeddings + chat)
- Functions:       $30 (executions)

💡 Optimization: Switch to cool storage tier → save $40/month
```

## Recommendations

### Short-Term (No Code Changes)

1. **Standardize Naming**: Enforce `proj{N}-*` pattern strictly
2. **Add Resource Tags**: Tag all resources with project number for cost tracking
3. **Document Runbooks**: Create step-by-step guides for common operations
4. **Azure Monitor Workbooks**: Build dashboards for 50-project overview

### Medium-Term (Backend APIs)

1. **Management API Service**: REST APIs for project CRUD operations
2. **Aggregation Endpoints**: APIs that query across all 50 projects
3. **APIM Integration**: Expose management APIs securely
4. **Status Dashboard**: Simple web UI showing all projects

### Long-Term (AI Agents) ⭐ Recommended

1. **Deploy 6 management agents** as outlined in main document
2. **Natural language interface** for complex operations
3. **Proactive monitoring** with intelligent alerts
4. **Automated remediation** for common issues

---

**Next Document**: [Agent Architecture Design](./agent-architecture.md)
