# Open WebUI API Routes Analysis

## Router Organization

Location: `/backend/open_webui/routers/`

Open WebUI uses a **domain-driven router architecture** where each business domain gets its own router file. This provides excellent separation of concerns and makes the codebase highly maintainable.

## Complete Router Inventory

### Core Chat & Communication (6 routers)

| Router | File | Purpose | Key Endpoints | Lines |
|--------|------|---------|---------------|-------|
| **Chats** | chats.py | Chat session CRUD | `/api/v1/chats` | ~150 |
| **Channels** | channels.py | Communication channels | `/api/v1/channels` | ~100 |
| **Notes** | notes.py | User notes | `/api/v1/notes` | ~80 |
| **Folders** | folders.py | Chat organization | `/api/v1/folders` | ~90 |
| **Memories** | memories.py | Conversation memory | `/api/v1/memories` | ~120 |
| **Prompts** | prompts.py | Prompt templates | `/api/v1/prompts` | ~100 |

### AI Model Integration (3 routers)

| Router | File | Purpose | Key Endpoints | Lines |
|--------|------|---------|---------------|-------|
| **Models** | models.py | Model management | `/api/v1/models` | ~180 |
| **Ollama** | ollama.py | Ollama proxy | `/ollama/*` | ~250 |
| **OpenAI** | openai.py | OpenAI compatibility | `/api/openai/*` | ~300 |

### RAG & Knowledge (3 routers)

| Router | File | Purpose | Key Endpoints | Lines |
|--------|------|---------|---------------|-------|
| **Retrieval** | retrieval.py | RAG queries | `/api/v1/retrieval` | ~200 |
| **Knowledge** | knowledge.py | Knowledge base | `/api/v1/knowledge` | ~150 |
| **Files** | files.py | Document upload/mgmt | `/api/v1/files` | ~200 |

### Media Processing (2 routers)

| Router | File | Purpose | Key Endpoints | Lines |
|--------|------|---------|---------------|-------|
| **Audio** | audio.py | STT/TTS | `/api/v1/audio` | ~180 |
| **Images** | images.py | Image generation | `/api/v1/images` | ~150 |

### User Management (3 routers)

| Router | File | Purpose | Key Endpoints | Lines |
|--------|------|---------|---------------|-------|
| **Users** | users.py | User CRUD | `/api/v1/users` | ~200 |
| **Groups** | groups.py | User groups | `/api/v1/groups` | ~120 |
| **Auths** | auths.py | Authentication | `/api/v1/auths` | ~250 |
| **SCIM** | scim.py | Enterprise provisioning | `/scim/v2/*` | ~180 |

### Extensibility (4 routers)

| Router | File | Purpose | Key Endpoints | Lines |
|--------|------|---------|---------------|-------|
| **Functions** | functions.py | Custom Python functions | `/api/v1/functions` | ~150 |
| **Tools** | tools.py | Tool management | `/api/v1/tools` | ~130 |
| **Pipelines** | pipelines.py | Plugin pipelines | `/api/v1/pipelines` | ~140 |
| **Tasks** | tasks.py | Background tasks | `/api/v1/tasks` | ~100 |

### System Management (3 routers)

| Router | File | Purpose | Key Endpoints | Lines |
|--------|------|---------|---------------|-------|
| **Configs** | configs.py | App configuration | `/api/v1/configs` | ~200 |
| **Evaluations** | evaluations.py | Model evaluation | `/api/v1/evaluations` | ~100 |
| **Utils** | utils.py | Utilities | `/api/version`, `/api/health` | ~80 |

**Total**: 25 routers, ~3,800 lines of router code

## Router Pattern Analysis

### Standard CRUD Router Pattern

```python
# Example from routers/chats.py (simplified)
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional

from open_webui.models.chats import Chats
from open_webui.utils.auth import get_current_user, get_admin_user
from open_webui.config import CONFIG

router = APIRouter(prefix="/api/v1/chats", tags=["chats"])

class ChatForm(BaseModel):
    title: str
    model: str
    messages: list

# LIST - Get all chats for user
@router.get("/")
async def get_chats(user=Depends(get_current_user)):
    """Get all chats for the authenticated user"""
    return Chats.get_chats_by_user_id(user.id)

# CREATE - Create new chat
@router.post("/")
async def create_chat(
    form_data: ChatForm, 
    user=Depends(get_current_user)
):
    """Create a new chat session"""
    chat = Chats.insert_new_chat(
        user_id=user.id,
        form_data=form_data
    )
    return chat

# READ - Get chat by ID
@router.get("/{id}")
async def get_chat_by_id(
    id: str, 
    user=Depends(get_current_user)
):
    """Get a specific chat"""
    chat = Chats.get_chat_by_id(id)
    if not chat or chat.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found"
        )
    return chat

# UPDATE - Update chat
@router.patch("/{id}")
async def update_chat(
    id: str,
    form_data: ChatForm,
    user=Depends(get_current_user)
):
    """Update an existing chat"""
    chat = Chats.get_chat_by_id(id)
    if not chat or chat.user_id != user.id:
        raise HTTPException(status_code=404)
    
    updated = Chats.update_chat_by_id(id, form_data)
    return updated

# DELETE - Delete chat
@router.delete("/{id}")
async def delete_chat(
    id: str, 
    user=Depends(get_current_user)
):
    """Delete a chat"""
    result = Chats.delete_chat_by_id(id, user.id)
    if not result:
        raise HTTPException(status_code=404)
    return {"success": True}

# ADMIN - Get all chats (admin only)
@router.get("/admin/all")
async def get_all_chats(user=Depends(get_admin_user)):
    """Admin endpoint to get all chats"""
    return Chats.get_all_chats()
```

### Key Pattern Elements

1. **Dependency Injection**: `Depends(get_current_user)` for auth
2. **Pydantic Models**: Type-safe request/response validation
3. **HTTP Status Codes**: Proper RESTful status codes
4. **Error Handling**: HTTPException for errors
5. **Authorization**: User-based access control
6. **Clear Naming**: Verb-based function names

## EVA-JP v1.2 Current Structure

### Current app.py Organization (2300+ lines)

```python
# app/backend/app.py - All routes in one file

# Health endpoint (~line 200)
@app.get("/api/health")
async def health():
    return {"status": "healthy"}

# Chat endpoints (~line 300-600)
@app.post("/api/chat")
async def chat(request: Request):
    # 200+ lines of chat logic
    pass

@app.post("/api/chat/stream")
async def chat_stream(request: Request):
    # 150+ lines of streaming logic
    pass

# Document endpoints (~line 700-1000)
@app.post("/api/upload")
async def upload_file(file: UploadFile):
    # 150+ lines of upload logic
    pass

@app.get("/api/documents")
async def list_documents():
    # Document listing logic
    pass

@app.delete("/api/documents/{id}")
async def delete_document(id: str):
    # Delete logic
    pass

# Search endpoints (~line 1100-1300)
@app.post("/api/search")
async def search(query: SearchQuery):
    # 200+ lines of search logic
    pass

# Admin endpoints (~line 1400-1600)
@app.get("/api/admin/users")
async def list_users():
    pass

# ... many more endpoints (~2300 lines total)
```

### Issues with Current Structure

❌ **Single file**: Hard to navigate 2300+ lines  
❌ **Mixed concerns**: Chat, documents, admin, search all together  
❌ **Difficult testing**: Hard to test individual domains  
❌ **Merge conflicts**: Multiple developers editing same file  
❌ **No clear ownership**: Unclear which team owns what  
❌ **Hard to extend**: Adding features requires editing massive file

## Proposed EVA Router Refactoring

### Target Router Structure

```
app/backend/routers/
├── __init__.py
├── chat.py              # Chat operations
├── documents.py         # Document CRUD
├── search.py            # Search & RAG
├── users.py             # User management
├── admin.py             # Admin operations
├── enrichment.py        # Enrichment pipeline
├── analytics.py         # Usage analytics
├── sharelinks.py        # Existing share router (keep)
├── oai.py              # Existing OpenAI router (keep)
└── health.py            # Health checks
```

### Migration Plan by Router

#### 1. chat.py (~200 lines)

```python
# app/backend/routers/chat.py
from fastapi import APIRouter, Depends, Request
from approaches import Approaches, get_approach
from core.auth import get_current_user, get_rbac_context

router = APIRouter(prefix="/api/chat", tags=["chat"])

@router.post("/")
async def chat(
    request: Request,
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """Process chat query"""
    # Move logic from app.py lines 300-500
    pass

@router.post("/stream")
async def chat_stream(
    request: Request,
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """Stream chat response"""
    # Move logic from app.py lines 500-650
    pass

@router.get("/history")
async def get_chat_history(user=Depends(get_current_user)):
    """Get user's chat history"""
    pass

@router.delete("/history/{chat_id}")
async def delete_chat(chat_id: str, user=Depends(get_current_user)):
    """Delete a chat session"""
    pass
```

#### 2. documents.py (~250 lines)

```python
# app/backend/routers/documents.py
from fastapi import APIRouter, UploadFile, File, Depends
from core.auth import get_current_user, get_rbac_context
from core.storage import upload_to_blob, delete_from_blob

router = APIRouter(prefix="/api/documents", tags=["documents"])

@router.post("/upload")
async def upload_document(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """Upload a document"""
    # Move logic from app.py lines 700-850
    # - Validate file
    # - Check RBAC permissions
    # - Upload to blob storage
    # - Trigger enrichment
    pass

@router.get("/")
async def list_documents(
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """List accessible documents"""
    # Move logic from app.py lines 850-950
    pass

@router.get("/{document_id}")
async def get_document(
    document_id: str,
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """Get document metadata"""
    pass

@router.delete("/{document_id}")
async def delete_document(
    document_id: str,
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """Delete a document"""
    # Move logic from app.py lines 950-1050
    pass

@router.get("/{document_id}/download")
async def download_document(
    document_id: str,
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """Download document file"""
    pass
```

#### 3. search.py (~200 lines)

```python
# app/backend/routers/search.py
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from approaches import get_approach
from core.auth import get_current_user, get_rbac_context

router = APIRouter(prefix="/api/search", tags=["search"])

class SearchQuery(BaseModel):
    query: str
    approach: str
    top: int = 5
    filters: dict = {}

@router.post("/")
async def search_documents(
    query: SearchQuery,
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """Search documents with RAG"""
    # Move logic from app.py lines 1100-1300
    approach = get_approach(query.approach)
    results = await approach.run(
        query.query,
        user=user,
        rbac=rbac
    )
    return results

@router.post("/ask")
async def ask_question(
    query: SearchQuery,
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """Ask a question (RAG)"""
    pass

@router.get("/indexes")
async def list_indexes(
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    """List accessible search indexes"""
    pass
```

#### 4. enrichment.py (~150 lines)

```python
# app/backend/routers/enrichment.py
from fastapi import APIRouter, Depends, BackgroundTasks
from core.auth import get_admin_user

router = APIRouter(
    prefix="/api/enrichment", 
    tags=["enrichment"],
    dependencies=[Depends(get_admin_user)]  # Admin only
)

@router.post("/trigger/{document_id}")
async def trigger_enrichment(
    document_id: str,
    background_tasks: BackgroundTasks
):
    """Manually trigger enrichment"""
    # Move from app.py
    pass

@router.get("/status/{document_id}")
async def get_enrichment_status(document_id: str):
    """Get enrichment status"""
    pass

@router.get("/pipeline")
async def get_pipeline_config():
    """Get enrichment pipeline configuration"""
    pass
```

## Router Registration in main.py

### OpenWebUI Pattern

```python
# backend/open_webui/main.py
from open_webui.routers import (
    audio, images, ollama, openai, retrieval,
    pipelines, tasks, auths, channels, chats,
    notes, folders, configs, groups, files,
    functions, memories, models, knowledge,
    prompts, evaluations, tools, users, utils, scim
)

# ... app initialization ...

# Register all routers
app.include_router(auths.router)
app.include_router(users.router)
app.include_router(chats.router)
app.include_router(models.router)
app.include_router(retrieval.router)
app.include_router(files.router)
# ... etc for all 25 routers
```

### EVA Target Pattern

```python
# app/backend/main.py (new file)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import routers

from routers import (
    chat, documents, search, users, admin,
    enrichment, analytics, sharelinks, oai, health
)
from core.auth import setup_auth_middleware
from core.rbac import setup_rbac_middleware

app = FastAPI(title="EVA Jurisprudence Assistant")

# Middleware
app.add_middleware(CORSMiddleware, ...)
setup_auth_middleware(app)
setup_rbac_middleware(app)

# Register routers
app.include_router(health.router)
app.include_router(chat.router)
app.include_router(documents.router)
app.include_router(search.router)
app.include_router(users.router)
app.include_router(admin.router)
app.include_router(enrichment.router)
app.include_router(analytics.router)
app.include_router(sharelinks.router)  # existing
app.include_router(oai.router)  # existing

# Legacy support during migration
if ENABLE_LEGACY_ROUTES:
    from legacy import app as legacy_app
    app.mount("/legacy", legacy_app)
```

## Benefits of Modular Router Architecture

### 1. Maintainability
✅ Each file ~150 lines (vs 2300 in one file)  
✅ Clear responsibility per router  
✅ Easy to find and fix bugs  
✅ Better code organization

### 2. Team Collaboration
✅ Multiple developers can work simultaneously  
✅ Fewer merge conflicts  
✅ Clear ownership by domain  
✅ Easier code reviews

### 3. Testing
✅ Test routers independently  
✅ Mock dependencies easily  
✅ Better test organization  
✅ Faster test execution

### 4. Extensibility
✅ Add new routers without touching existing code  
✅ Easy to add middleware per router  
✅ Version APIs incrementally  
✅ Deprecate old endpoints cleanly

### 5. Performance
✅ Lazy loading possible  
✅ Better caching opportunities  
✅ Easier to optimize individual routers  
✅ Clear performance bottlenecks

## Migration Strategy

### Phase 1: Create Router Structure (Week 1)
1. Create `routers/` directory
2. Create `__init__.py`
3. Create empty router files
4. Set up router registration in new `main.py`

### Phase 2: Extract Routes (Week 2-3)
1. Move health/utility routes first (low risk)
2. Move chat routes
3. Move document routes
4. Move search routes
5. Keep legacy `app.py` as fallback

### Phase 3: Clean Up (Week 4)
1. Update all imports
2. Update tests
3. Remove legacy code
4. Update documentation

### Phase 4: Enhanced Patterns (Week 5+)
1. Add middleware per router
2. Implement rate limiting
3. Add WebSocket support
4. Enhance error handling

## Testing Strategy

### Router Unit Tests

```python
# tests/routers/test_chat.py
from fastapi.testclient import TestClient
from app.main import app
from tests.fixtures import mock_user, mock_rbac

client = TestClient(app)

def test_create_chat(mock_user):
    response = client.post(
        "/api/chat",
        json={"query": "test"},
        headers={"Authorization": f"Bearer {mock_user.token}"}
    )
    assert response.status_code == 200
    assert "response" in response.json()

def test_chat_requires_auth():
    response = client.post("/api/chat", json={"query": "test"})
    assert response.status_code == 401

def test_chat_respects_rbac(mock_user, mock_rbac):
    # Test RBAC enforcement
    pass
```

## Next Steps

1. Review [FastAPI Patterns](FASTAPI-PATTERNS.md) for implementation best practices
2. Check [EVA Integration Plan](../integration/EVA-INTEGRATION-PLAN.md) for migration timeline
3. Study [Backend Mapping](../integration/BACKEND-MAPPING.md) for code mapping details

---

**Created**: 2026-02-07  
**Focus**: Router architecture and refactoring strategy  
**Target**: Break down EVA's monolithic app.py into modular routers
