# EVA-OpenWebUI Integration Plan

## Executive Summary

**Objective**: Modernize EVA Jurisprudence Assistant (v1.2) by adopting proven architectural patterns from Open WebUI while maintaining Azure-native advantages and enterprise requirements.

**Timeline**: 4 months  
**Risk Level**: Medium  
**Impact**: High - Improved maintainability, scalability, developer experience

## Current State Analysis

### EVA-JP v1.2 Strengths
✅ Azure-native integration (Cosmos, Blob, AI Search, Azure OpenAI)  
✅ Enterprise RBAC with Azure AD  
✅ Custom enrichment pipeline for document processing  
✅ Government compliance focus  
✅ Production-ready security model  
✅ Proven performance with real users

### EVA-JP v1.2 Pain Points
❌ Monolithic app.py (2300+ lines) - Hard to maintain  
❌ Limited real-time features  
❌ No WebSocket support  
❌ Minimal middleware stack  
❌ No plugin/extension system  
❌ Frontend using older UI libraries  
❌ Limited horizontal scalability

### Open WebUI Strengths to Adopt
✅ Modular router architecture (25+ routers)  
✅ Comprehensive middleware stack  
✅ WebSocket support via Socket.io  
✅ Plugin system (Pipelines framework)  
✅ Modern frontend with Tailwind  
✅ Abstract data layer for flexibility  
✅ Built-in observability  
✅ Horizontal scalability with Redis

## Integration Strategy

### Core Principle
> **"Adopt patterns, not technology"**  
> Keep EVA's Azure-native foundation while modernizing architecture

### What to Adopt
- ✅ Router modularity pattern
- ✅ Middleware architecture
- ✅ WebSocket implementation approach
- ✅ Plugin system concept (EVA-adapted)
- ✅ Frontend component patterns
- ✅ Configuration management approach

### What to Keep
- ✅ Azure services (Cosmos, Blob, AI Search, Azure AD)
- ✅ React framework (team expertise)
- ✅ RBAC implementation
- ✅ Enrichment pipeline
- ✅ Compliance requirements

## 4-Month Roadmap

### Month 1: Backend Refactoring

#### Week 1-2: Router Infrastructure
**Goal**: Set up modular router structure

**Tasks**:
- [ ] Create `routers/` directory structure
- [ ] Extract health/utility routes (low risk)
- [ ] Create router registration system
- [ ] Set up parallel app.py and new main.py
- [ ] Update CI/CD for dual deployment

**Deliverables**:
```
app/backend/
├── main.py (new)
├── app.py (legacy, maintain)
├── routers/
│   ├── __init__.py
│   ├── health.py ✅
│   ├── chat.py ⏳
│   ├── documents.py ⏳
│   └── ...
```

**Success Criteria**:
- ✅ Health endpoints functional via new routers
- ✅ Legacy app.py still working
- ✅ Zero downtime deployment
- ✅ All tests passing

#### Week 3-4: Core Router Migration
**Goal**: Migrate main business logic to routers

**Tasks**:
- [ ] Extract chat router (~200 lines)
- [ ] Extract documents router (~250 lines)
- [ ] Extract search router (~200 lines)
- [ ] Extract user router (~150 lines)
- [ ] Update all route tests
- [ ] Performance testing

**Code Migration**:
```python
# From app.py (lines 300-500)
@app.post("/api/chat")
async def chat(request: Request):
    # 200 lines...

# To routers/chat.py
from fastapi import APIRouter, Depends
router = APIRouter(prefix="/api/chat", tags=["chat"])

@router.post("/")
async def chat(
    request: Request,
    user=Depends(get_current_user),
    rbac=Depends(get_rbac_context)
):
    # Same logic, better organized
```

**Success Criteria**:
- ✅ 80% of routes migrated to routers
- ✅ Response time unchanged (< 5% variance)
- ✅ All existing tests pass
- ✅ New router tests added

#### Month 1 Deliverables
- ✅ Modular router architecture implemented
- ✅ 80%+ code migrated
- ✅ Documentation updated
- ✅ Performance verified

---

### Month 2: Middleware & Real-time Features

#### Week 5-6: Middleware Stack
**Goal**: Implement comprehensive middleware

**Tasks**:
- [ ] Audit logging middleware
- [ ] Rate limiting middleware (per user/IP)
- [ ] Request tracing middleware
- [ ] Compression middleware
- [ ] Error handling middleware
- [ ] Session management enhancement

**Implementation**:
```python
# app/backend/middleware/audit.py
from starlette.middleware.base import BaseHTTPMiddleware

class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        # Log request
        user = request.state.user if hasattr(request.state, 'user') else None
        log_request(user, request.method, request.url)
        
        response = await call_next(request)
        
        # Log response
        log_response(user, response.status_code)
        return response

# Register in main.py
app.add_middleware(AuditMiddleware)
```

**Success Criteria**:
- ✅ All requests logged
- ✅ Rate limiting prevents abuse
- ✅ Compression reduces bandwidth 30%+
- ✅ Error tracking integrated

#### Week 7-8: WebSocket Support
**Goal**: Enable real-time features

**Tasks**:
- [ ] Install and configure Socket.io
- [ ] Create WebSocket router
- [ ] Implement chat streaming via WebSocket
- [ ] Document status updates (real-time)
- [ ] Multi-user collaboration features
- [ ] Frontend WebSocket client

**Implementation**:
```python
# app/backend/socket/main.py
from socketio import AsyncServer
import socketio

sio = AsyncServer(async_mode='asgi', cors_allowed_origins='*')
socket_app = socketio.ASGIApp(sio)

@sio.event
async def connect(sid, environ):
    print(f"Client {sid} connected")

@sio.on('chat_message')
async def handle_chat(sid, data):
    user = get_user_from_session(sid)
    response = await process_chat_streaming(data, user)
    async for chunk in response:
        await sio.emit('chat_chunk', chunk, room=sid)

# Mount in main.py
app.mount("/ws", socket_app)
```

**Use Cases**:
1. **Streaming Chat**: Real-time token-by-token responses
2. **Document Status**: Live enrichment progress
3. **Collaborative Search**: Multiple users see same results
4. **Notifications**: System alerts and updates

**Success Criteria**:
- ✅ WebSocket connections stable
- ✅ Chat streaming implemented
- ✅ Document status real-time
- ✅ < 50ms latency

#### Month 2 Deliverables
- ✅ 6+ middleware components
- ✅ WebSocket infrastructure
- ✅ Real-time chat streaming
- ✅ 30% bandwidth reduction

---

### Month 3: Frontend Modernization

#### Week 9-10: Tailwind CSS Migration
**Goal**: Modernize UI with Tailwind

**Tasks**:
- [ ] Install Tailwind CSS 4.0
- [ ] Configure Tailwind for React
- [ ] Create design system tokens
- [ ] Migrate common components
- [ ] Implement dark mode
- [ ] Update stylesheet imports

**Migration Example**:
```tsx
// Before: Fluent UI
import { Stack, TextField } from '@fluentui/react';

<Stack>
  <TextField label="Search" />
</Stack>

// After: Tailwind + Headless UI
import { Input } from '@/components/ui/input';

<div className="space-y-4">
  <Input 
    label="Search"
    className="w-full rounded-lg border border-gray-300 dark:border-gray-700"
  />
</div>
```

**Component Library**:
```
app/frontend/src/components/ui/
├── button.tsx
├── input.tsx
├── card.tsx
├── dialog.tsx
├── dropdown.tsx
└── ... (shadcn/ui inspired)
```

**Success Criteria**:
- ✅ Tailwind integrated
- ✅ 50% components migrated
- ✅ Dark mode working
- ✅ Bundle size reduced 20%+

#### Week 11-12: State Management & Components
**Goal**: Improve frontend architecture

**Tasks**:
- [ ] Implement Zustand for global state
- [ ] Create component library
- [ ] Add WebSocket client integration
- [ ] Refactor chat components
- [ ] Mobile responsive improvements
- [ ] Performance optimization

**State Management**:
```typescript
// app/frontend/src/stores/chat.ts
import create from 'zustand';

interface ChatState {
  messages: Message[];
  isStreaming: boolean;
  addMessage: (msg: Message) => void;
  streamMessage: (chunk: string) => void;
}

export const useChatStore = create<ChatState>((set) => ({
  messages: [],
  isStreaming: false,
  addMessage: (msg) => set((state) => ({ 
    messages: [...state.messages, msg] 
  })),
  streamMessage: (chunk) => set((state) => ({
    // Update last message with chunk
  }))
}));
```

**Success Criteria**:
- ✅ Zustand integrated
- ✅ Component library established
- ✅ Real-time UI updates via WebSocket
- ✅ Lighthouse score > 90

#### Month 3 Deliverables
- ✅ Tailwind CSS integrated
- ✅ Dark mode support
- ✅ Modern component library
- ✅ Improved state management
- ✅ 20%+ bundle size reduction

---

### Month 4: Extensibility & Polish

#### Week 13-14: Plugin System (EVA Pipelines)
**Goal**: Enable extensibility

**Tasks**:
- [ ] Design EVA Pipelines framework
- [ ] Create plugin interface
- [ ] Implement pre/post-processing hooks
- [ ] Create example plugins
- [ ] Developer documentation

**Plugin System**:
```python
# app/backend/pipelines/base.py
from abc import ABC, abstractmethod

class Pipeline(ABC):
    """Base class for EVA pipelines"""
    
    @abstractmethod
    async def process(self, data: dict, context: dict) -> dict:
        """Process data through pipeline"""
        pass
    
    async def pre_process(self, data: dict) -> dict:
        """Pre-processing hook"""
       return data
    
    async def post_process(self, data: dict) -> dict:
        """Post-processing hook"""
        return data

# Example: Custom enrichment pipeline
class CustomEnrichment(Pipeline):
    async def process(self, data, context):
        # Custom enrichment logic
        document = data['document']
        enriched = await custom_extraction(document)
        return {'enriched_document': enriched}

# Register pipeline
pipelines.register('custom-enrichment', CustomEnrichment())
```

**Use Cases**:
1. Custom document extractors
2. Query transformers
3. Response post-processors
4. External API integrations
5. Custom validators

**Success Criteria**:
- ✅ Plugin framework working
- ✅ 3+ example plugins
- ✅ Developer docs complete
- ✅ Hot-reload support

#### Week 15-16: Performance & Observability
**Goal**: Production-ready optimization

**Tasks**:
- [ ] Add Redis caching layer
- [ ] Implement query result caching
- [ ] Database query optimization
- [ ] API response compression
- [ ] Azure Monitor integration
- [ ] Performance dashboard
- [ ] Load testing

**Caching Strategy**:
```python
# app/backend/core/cache.py
from redis import Redis
import json

cache = Redis(host='redis', port=6379, decode_responses=True)

async def cached_search(query: str, user_id: str):
    """Cache search results"""
    cache_key = f"search:{user_id}:{hash(query)}"
    
    # Check cache
    cached = cache.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # Execute search
    results = await search_documents(query, user_id)
    
    # Cache for 5 minutes
    cache.setex(cache_key, 300, json.dumps(results))
    return results
```

**Observability**:
```python
# Azure Monitor integration
from azure.monitor.opentelemetry import configure_azure_monitor

configure_azure_monitor(
    connection_string=APPLICATIONINSIGHTS_CONNECTION_STRING
)

# Request tracking
@router.post("/api/chat")
@traced("chat_request")
async def chat(request: Request):
    with tracer.start_as_current_span("process_chat"):
        # Track performance
        pass
```

**Success Criteria**:
- ✅ Redis integrated
- ✅ 50% cache hit rate on searches
- ✅ p95 latency < 200ms
- ✅ Observability dashboard
- ✅ Load test: 500+ concurrent users

#### Month 4 Deliverables
- ✅ Plugin system functional
- ✅ Redis caching layer
- ✅ Performance optimized
- ✅ Full observability
- ✅ Load testing passed

---

## Technical Architecture After Integration

### Backend Structure
```
app/backend/
├── main.py                    # FastAPI app with router registration
├── app.py                     # Legacy (deprecated, remove after stabilization)
├── routers/                   # ✨ NEW: Modular routers
│   ├── chat.py
│   ├── documents.py
│   ├── search.py
│   ├── users.py
│   ├── admin.py
│   ├── enrichment.py
│   └── analytics.py
├── middleware/                # ✨ NEW: Middleware stack
│   ├── audit.py
│   ├── rate_limit.py
│   ├── compression.py
│   └── tracing.py
├── socket/                    # ✨ NEW: WebSocket support
│   ├── __init__.py
│   └── main.py
├── pipelines/                 # ✨ NEW: Plugin system
│   ├── base.py
│   ├── registry.py
│   └── examples/
├── core/                      # Enhanced core utilities
│   ├── auth.py
│   ├── rbac.py
│   ├── cache.py              # ✨ NEW: Redis caching
│   └── config.py
├── approaches/                # Existing (keep)
└── functions/                 # Existing (keep)
```

### Frontend Structure
```
app/frontend/
├── src/
│   ├── components/
│   │   ├── ui/               # ✨ NEW: Component library
│   │   │   ├── button.tsx
│   │   │   ├── input.tsx
│   │   │   └── ...
│   │   ├── chat/             # Enhanced
│   │   ├── documents/        # Enhanced
│   │   └── layout/
│   ├── stores/               # ✨ NEW: Zustand stores
│   │   ├── chat.ts
│   │   ├── documents.ts
│   │   └── user.ts
│   ├── hooks/                # Custom React hooks
│   ├── services/             # API clients
│   │   ├── chat.ts
│   │   ├── websocket.ts     # ✨ NEW: WebSocket client
│   │   └── documents.ts
│   ├── styles/
│   │   └── tailwind.css      # ✨ NEW: Tailwind
│   └── App.tsx
└── package.json              # Updated dependencies
```

## Risk Management

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Breaking changes during refactor** | High | High | - Feature flags<br>- Parallel deployment<br>- Gradual rollout<br>- Comprehensive testing |
| **Performance regression** | Medium | High | - Load testing before each phase<br>- Performance baseline<br>- Rollback plan |
| **Team learning curve** | Medium | Medium | - Training sessions<br>- Pair programming<br>- Clear documentation |
| **Azure-specific features lost** | Low | High | - Careful abstraction design<br>- Keep Azure as primary |
| **Timeline delays** | Medium | Medium | - Buffer time in schedule<br>- Prioritize critical features |
| **User disruption** | Low | High | - Zero-downtime deployment<br>- Beta testing with subset |

## Testing Strategy

### Unit Tests
```python
# tests/routers/test_chat.py
def test_chat_endpoint(client, mock_user):
    response = client.post(
        "/api/chat",
        json={"query": "test"},
        headers={"Authorization": f"Bearer {mock_user.token}"}
    )
    assert response.status_code == 200

def test_chat_requires_auth(client):
    response = client.post("/api/chat", json={"query": "test"})
    assert response.status_code == 401
```

### Integration Tests
```python
# tests/integration/test_chat_flow.py
async def test_full_chat_flow(client, mock_user, mock_documents):
    # Upload document
    upload_response = await client.post("/api/documents/upload", ...)
    
    # Wait for enrichment
    await wait_for_enrichment(upload_response.id)
    
    # Query document
    chat_response = await client.post("/api/chat", ...)
    assert "answer" in chat_response.json()
```

### Load Tests
```python
# tests/load/test_concurrent_users.py
from locust import HttpUser, task, between

class EVAUser(HttpUser):
    wait_time = between(1, 3)
    
    @task
    def chat(self):
        self.client.post("/api/chat", json={"query": "test"})
    
    @task
    def search(self):
        self.client.post("/api/search", json={"query": "legal"})

# Run: locust -f tests/load/test_concurrent_users.py --users 500
```

## Success Metrics

### Performance
- ✅ API p95 latency < 200ms
- ✅ WebSocket latency < 50ms
- ✅ Frontend bundle < 500KB
- ✅ Cache hit rate > 50%
- ✅ Support 500+ concurrent users

### Code Quality
- ✅ Test coverage > 80%
- ✅ No files > 300 lines
- ✅ TypeScript strict mode
- ✅ Zero critical security issues
- ✅ Lighthouse score > 90

### Developer Experience
- ✅ Setup time < 30 min
- ✅ Hot reload working
- ✅ Clear documentation
- ✅ Plugin development < 1 day

### User Experience
- ✅ Chat response time < 2s
- ✅ Document upload success > 99%
- ✅ Mobile usable (Lighthouse mobile > 80)
- ✅ Dark mode working
- ✅ Zero downtime deployments

## Rollout Strategy

### Phase A: Internal Testing (Week 1-2 per month)
- Deploy to dev environment
- Internal team testing
- Performance validation
- Bug fixes

### Phase B: Beta Testing (Week 3 per month)
- Deploy to staging
- Select beta users (10-20)
- Gather feedback
- Iterate

### Phase C: Production Rollout (Week 4 per month)
- Gradual rollout (10% → 50% → 100%)
- Monitor metrics
- Rollback if needed
- Document lessons learned

## Migration Checklist

### Pre-Migration
- [ ] Backup production database
- [ ] Document current architecture
- [ ] Set up staging environment
- [ ] Create rollback plan
- [ ] Train team on new patterns

### Month 1
- [ ] Router infrastructure
- [ ] Core routes migrated
- [ ] Tests updated
- [ ] Performance validated
- [ ] Documentation updated

### Month 2
- [ ] Middleware stack
- [ ] WebSocket support
- [ ] Real-time features
- [ ] Load testing passed

### Month 3
- [ ] Tailwind integrated
- [ ] Component library
- [ ] Dark mode
- [ ] Mobile optimized

### Month 4
- [ ] Plugin system
- [ ] Redis caching
- [ ] Observability dashboard
- [ ] Final performance tuning

### Post-Migration
- [ ] Legacy code removed
- [ ] Final documentation
- [ ] Team training complete
- [ ] Production monitoring active

## Conclusion

This integration plan provides a structured, low-risk approach to modernizing EVA-JP v1.2 by adopting proven patterns from Open WebUI while maintaining Azure-native advantages.

**Expected Outcomes**:
- 📦 Better code organization (25+ modular routers)
- ⚡ Improved performance (caching, optimization)
- 🔌 Extensibility (plugin system)
- 🎨 Modern UI (Tailwind, dark mode)
- 📊 Better observability (monitoring, tracing)
- 👥 Improved developer experience

**Next Steps**:
1. Get stakeholder approval
2. Set up project tracking
3. Begin Month 1, Week 1 tasks
4. Schedule weekly checkpoints

---

**Created**: 2026-02-07  
**Owner**: EVA Development Team  
**Timeline**: 4 months  
**Status**: 🟡 Ready for Review
