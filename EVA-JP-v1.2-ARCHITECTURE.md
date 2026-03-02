# EVA Jurisprudence v1.2 - Complete Architecture Reference

> **Document Purpose**: Comprehensive technical documentation of the production EVA Domain Assistant - EI Jurisprudence (EVA DA JP) v1.2 system architecture, serving as the baseline reference for EVA Brain decomposition project.

**Location**: `C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2`  
**Status**: Production (EsPAICOESub subscription)  
**Go-Live Deadline**: March 31, 2026  
**Last Updated**: February 7, 2026

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [System Overview](#system-overview)
- [Frontend Architecture](#frontend-architecture)
- [Backend Architecture](#backend-architecture)
- [Deployment Configuration](#deployment-configuration)
- [Development Standards](#development-standards)
- [Key Integration Points](#key-integration-points)

---

## Executive Summary

**EVA Domain Assistant - EI Jurisprudence (EVA DA JP) version 1.2** is a production-grade Azure OpenAI-powered copilot built on the Microsoft Information Assistant template. It serves Employment and Social Development Canada (ESDC) Service Officers for Employment Insurance claim assistance.

**Critical Characteristics**:
- **Architecture Pattern**: Monolithic React + Flask + Azure Services
- **Deployment Mode**: Secure mode with network isolation
- **Authentication**: Azure AD with role-based access control (RBAC)
- **Compliance**: ESDC security standards, IT-SG333, content filtering
- **Scale**: Production workload, multi-tenant (group-based isolation)

**Strategic Context**: This monolith is the target for EVA Brain decomposition into:
1. **EVA Brain Backend** (Intelligence Layer)
2. **EVA Face** (Universal API Facade)
3. **EVA Pipeline** (Document Enrichment)

---

## System Overview

### Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Frontend** | React + TypeScript | 18.2.0 | User interface |
| **Build Tool** | Vite | 6.3.5 | Frontend bundling |
| **UI Framework** | Fluent UI | 8.110.7 | Microsoft design system |
| **Backend** | FastAPI (Python) | Latest | API middleware |
| **AI Engine** | Azure OpenAI | GPT-4o | LLM reasoning |
| **Search** | Azure AI Search | Latest | RAG retrieval |
| **Database** | Cosmos DB | Latest | Session/logging |
| **Storage** | Azure Blob Storage | Latest | Document storage |
| **Auth** | Azure AD + RBAC | Latest | Security layer |

### Response Generation Approaches

The system supports 4 distinct modes:

1. **Work (Grounded)** - RAG pattern using Azure AI Search + GPT-4o
2. **Ungrounded** - Direct LLM responses (no retrieval)
3. **Work and Web** - Hybrid: internal docs + Bing Search with comparison
4. **Assistants** - Autonomous reasoning agents (preview)

---

## Frontend Architecture

### Directory Structure

```
app/frontend/
├── public/                      # Static assets
├── src/
│   ├── index.tsx                # App entry point (React Router)
│   ├── index.css                # Global styles
│   ├── vite-env.d.ts           # Type definitions
│   │
│   ├── pages/                   # Route-based pages
│   │   ├── layout/
│   │   │   └── Layout.tsx       # Main app shell with navigation
│   │   ├── chat/
│   │   │   └── Chat.tsx         # Primary chat interface (1028 lines)
│   │   ├── content/
│   │   │   └── Content.tsx      # Document management
│   │   ├── tda/
│   │   │   └── Tda.tsx          # Tabular Data Assistant
│   │   ├── translator/
│   │   │   └── Translator.tsx   # Translation feature
│   │   ├── tutor/
│   │   │   └── Tutor.tsx        # Tutorial/help mode
│   │   ├── urlscrapper/
│   │   │   └── Urlscrapper.tsx  # URL content extraction
│   │   └── NoPage.tsx           # 404 handler
│   │
│   ├── components/              # 25+ reusable components
│   │   ├── Answer/              # Response rendering
│   │   │   ├── Answer.tsx       # Main answer component
│   │   │   ├── AnswerParser.tsx # Markdown/citation parsing
│   │   │   ├── AnswerError.tsx  # Error display
│   │   │   ├── AnswerLoading.tsx # Loading states
│   │   │   └── FeedbackModal.tsx # User feedback
│   │   ├── ApplicationContext/  # Global state management
│   │   │   └── ApplicationContext.tsx
│   │   ├── ChatHistory/         # Session management
│   │   ├── ChatModeButtonGroup/ # Mode selector (Work/Web/Ungrounded)
│   │   ├── QuestionInput/       # User input field
│   │   ├── UserChatMessage/     # User message display
│   │   ├── AnalysisPanel/       # Response analysis sidebar
│   │   ├── SettingsButton/      # Configuration panel
│   │   ├── InfoButton/          # Help/info panel
│   │   ├── ClearChatButton/     # Session reset
│   │   ├── ResponseLengthButtonGroup/ # Token length control
│   │   ├── ResponseTempButtonGroup/   # Temperature control
│   │   ├── TagPicker/           # Document tag filtering
│   │   ├── FolderPicker/        # Folder filtering
│   │   ├── FileStatus/          # Upload status tracking
│   │   ├── Title/               # App branding
│   │   ├── WarningBanner/       # System notifications
│   │   ├── RAIPanel/            # Responsible AI info
│   │   ├── SupportingContent/   # Additional context
│   │   ├── CharacterStreamer/   # Streaming text display
│   │   └── Example/             # Example prompts
│   │
│   └── api/                     # Backend communication layer
│       ├── api.ts               # API functions (664 lines)
│       ├── models.ts            # TypeScript types (277 lines)
│       └── index.ts             # Public exports
│
├── vite.config.ts               # Build config + dev proxy
├── tsconfig.json                # TypeScript config
├── eslint.config.ts             # Linting rules
├── package.json                 # Dependencies
├── .env                         # Environment config (dev)
└── version.json                 # Build versioning
```

### Key Frontend Components

#### 1. **App Entry Point** (`src/index.tsx`)

```tsx
// React Router setup with HashRouter
<HashRouter>
  <Routes>
    <Route path="/" element={<Layout />}>
      <Route index element={<Chat />} />              {/* Main chat */}
      <Route path="content" element={<Content />} />  {/* Document mgmt */}
      <Route path="urlscrapper" element={<Urlscrapper />} />
      <Route path="translator" element={<Translator />} />
      <Route path="tutor" element={<Tutor />} />
      <Route path="tda" element={<Tda />} />
      <Route path="*" element={<NoPage />} />
    </Route>
  </Routes>
</HashRouter>
```

#### 2. **Layout Component** (`pages/layout/Layout.tsx`)

**Responsibilities**:
- App shell with navigation
- User authentication check
- RBAC group validation (GROUP_NAME required)
- Feature flags loading
- User info context provider

**Key Features**:
- Blocks unauthorized users with helpful documentation links
- Provides `UserInfoContext` for role-based UI
- Loads application title dynamically
- Manages feature flag state

#### 3. **Chat Component** (`pages/chat/Chat.tsx`)

**Size**: 1028 lines (largest component)  
**Core State**:
```typescript
// Session management
const [isSessionCreated, setIsSessionCreated] = useState(false);
const [chatHistory, setChatHistory] = useState<ChatSession[]>([]);
const [sessionId, setSessionId] = useState<string>("");

// Configuration
const [retrieveCount, setRetrieveCount] = useState<number>(5);
const [responseLength, setResponseLength] = useState<number>(2048);
const [responseTemp, setResponseTemp] = useState<number>(0.6);
const [activeChatMode, setChatMode] = useState<ChatMode>(ChatMode.WorkOnly);
const [activeApproach, setActiveApproach] = useState<number>(Approaches.ReadRetrieveRead);

// User preferences
const [userPersona, setUserPersona] = useState<string>("analyst");
const [systemPersona, setSystemPersona] = useState<string>("an Assistant");
const [useSuggestFollowupQuestions, setUseSuggestFollowupQuestions] = useState<boolean>(false);

// RBAC filtering
const [selectedTags, setSelectedTags] = useState<ITag[]>([]);
const [selectedFolders, setSelectedFolders] = useState<string[]>([]);
```

**Key Features**:
- Multi-session chat history
- Streaming responses with citation parsing
- Mode switching (Work/Web/Ungrounded)
- Approach selection (RAG strategies)
- Settings panel with 10+ configuration options
- RBAC-based document filtering (tags + folders)
- Export chat to PDF
- Feedback collection
- Custom error handling with ESDC contact emails

#### 4. **API Layer** (`api/api.ts`, `api/models.ts`)

**17+ API Endpoints**:
```typescript
// Core chat APIs
chatApi()                    // POST /chat - Streaming chat responses
getAllUploadStatus()         // POST /getalluploadstatus - Document status
getCitationFilePath()        // GET /getcitation - Retrieve citations
getInfoData()               // GET /getInfoData - System info
getFeatureFlags()           // GET /getFeatureFlags - Feature toggles
getApplicationTitle()       // GET /getApplicationTitle - Branding

// Session management
/sessions/*                 // Session CRUD (via router)

// Authentication & RBAC
getUsrGroupInfo()           // GET /getUsrGroupInfo - User's group info
updateUsrGroup()            // POST /updateUsrGroupInfo - Update group

// Document operations
deleteItems()               // POST /deleteItems - Delete documents
resubmitItems()             // POST /resubmitItems - Reprocess documents
getallTags()                // GET /getalltags - Available tags
getFolders()                // GET /getfolders - Available folders
getblobclienturl()          // GET /getblobclienturl - Blob SAS token

// Assistant agents
process_agent_response()    // POST /process_agent_response - Math assistant
process_td_agent_response() // POST /process_td_agent_response - Tabular data

// Utility
urlscrapper()               // POST /urlscrapper - Extract web content
translateFile()             // POST /translate - Document translation
logstatus()                 // POST /logstatus - Client-side logging
```

**TypeScript Models** (key types):
```typescript
export type ChatRequest = {
    history: ChatTurn[];
    approach: Approaches;
    overrides?: ChatRequestOverrides;
    citation_lookup: { [key: string]: Citation };
    thought_chain: { [key: string]: string };
};

export type ChatResponse = {
    answer: string;
    thoughts: string | null;
    data_points: string[];
    approach: Approaches;
    thought_chain: { [key: string]: string };
    work_citation_lookup: { [key: string]: Citation };
    web_citation_lookup: { [key: string]: Citation };
    error?: string;
    language?: string;
};

export type ChatSession = {
    id: string;
    title: string;
    createdAt: string;
    session_id: string;
};

export type FileUploadBasicStatus = {
    id: string;
    file_path: string;
    file_name: string;
    state: string;
    start_timestamp: string;
    state_description: string;
    state_timestamp: string;
    status_updates: StatusUpdates[];
    tags: string;
};
```

### Development Configuration

#### **Vite Config** (`vite.config.ts`)

**Dev Server Proxy** (port 3000 → 5000):
```typescript
server: {
    proxy: {
        "/ask": "http://localhost:5000",
        "/chat": "http://localhost:5000",
        "/sessions": "http://localhost:5000",
        "/getFeatureFlags": "http://localhost:5000",
        "/getalltags": "http://localhost:5000",
        // ... 17+ more endpoints
    }
}
```

**Build Output**:
```typescript
build: {
    outDir: "../backend/static",  // Frontend compiled into backend
    emptyOutDir: true,
    sourcemap: true,
    rollupOptions: {
        plugins: [rollupNodePolyFill(), nodePolyfills()]
    }
}
```

**Key Insight**: Frontend builds directly into backend's static folder, creating a **monolithic deployment** (single container serves both).

#### **Package.json Scripts**

```json
{
  "scripts": {
    "dev": "vite",                              // Dev server (port 3000)
    "build": "tsc --noEmit && vite build",      // Production build
    "watch": "tsc && vite build --watch",       // Watch mode
    "lint": "eslint .",                         // Code linting
    "format": "prettier --check ."              // Code formatting
  }
}
```

### Key Dependencies

**Core UI**:
- `@fluentui/react` (8.110.7) - Microsoft design system
- `@fluentui/react-icons` (2.0.195) - Icon library
- `react` (18.2.0) + `react-dom` (18.2.0)
- `react-router-dom` (6.8.1) - Routing

**Content Rendering**:
- `react-markdown` (10.1.0) - Markdown parsing
- `remark-gfm` (3.0.0) - GitHub Flavored Markdown
- `rehype-raw` (7.0.0) - HTML in markdown
- `rehype-sanitize` (6.0.0) - XSS protection
- `dompurify` (3.1.2) - HTML sanitization

**Data Handling**:
- `papaparse` (5.4.1) - CSV parsing
- `xlsx` (0.18.5) - Excel file handling
- `mammoth` (1.5.5) - Word document parsing

**Utilities**:
- `uuid` (11.1.0) - Unique IDs
- `nanoid` (3.3.11) - Short IDs
- `classnames` (2.3.1) - CSS class management
- `ndjson-readablestream` (1.2.0) - Streaming responses

---

## Backend Architecture

### Directory Structure

```
app/backend/
├── app.py                       # Main FastAPI application (2344 lines)
├── backend.env                  # Environment configuration
├── requirements.txt             # Python dependencies
│
├── approaches/                  # RAG strategy implementations
│   ├── approach.py              # Base approach interface
│   ├── chatreadretrieveread.py  # Main RAG approach
│   ├── chatwebretrieveread.py   # Web-augmented RAG
│   ├── compareworkwithweb.py    # Work→Web comparison
│   ├── comparewebwithwork.py    # Web→Work comparison
│   ├── gpt_direct_approach.py   # Ungrounded mode
│   ├── mathassistant.py         # Math problem agent
│   └── tabulardataassistant.py  # Data analysis agent
│
├── core/                        # Shared utilities
│   ├── shared_constants.py      # Config constants, Azure clients
│   └── utils.py                 # Helper functions
│
├── routers/                     # Modular route handlers
│   └── sessions.py              # Session management endpoints
│
├── appmodels/                   # Data models
│   └── apiresponses.py          # Response schemas
│
└── static/                      # Frontend build output (from Vite)
    ├── index.html
    ├── assets/
    └── ...
```

### Core Backend Components

#### 1. **Main Application** (`app.py`)

**Size**: 2344 lines  
**Framework**: FastAPI with async support

**Key Imports**:
```python
from fastapi import FastAPI, File, HTTPException, Request
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from azure.identity import get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.cosmos import CosmosClient
from azure.storage.blob import BlobServiceClient
```

**Core Features**:
- Azure OpenAI integration with AD authentication
- Cosmos DB session/logging
- Azure AI Search queries
- Blob storage document access
- RBAC enforcement via `shared_code.utility_rbck`
- Content safety filtering
- Streaming responses

**Authentication Flow**:
```python
# Azure AD token provider
token_provider = get_bearer_token_provider(
    AZURE_CREDENTIAL,
    f'https://{ENV["AZURE_AI_CREDENTIAL_DOMAIN"]}/.default'
)
openai.azure_ad_token_provider = token_provider

# RBAC validation
from shared_code.utility_rbck import (
    get_rbac_grplist_from_client_principle,
    find_container_and_role,
    find_index_and_role
)
```

#### 2. **RAG Approaches** (`approaches/`)

**Base Interface** (`approach.py`):
```python
class Approaches(Enum):
    RetrieveThenRead = 0
    ReadRetrieveRead = 1
    ReadDecomposeAsk = 2
    GPTDirect = 3
    ChatWebRetrieveRead = 4
    CompareWorkWithWeb = 5
    CompareWebWithWork = 6
```

**Main Implementation** (`chatreadretrieveread.py`):
- Query Azure AI Search (hybrid: vector + keyword)
- Retrieve top-K documents (configurable: default 5)
- Construct prompt with context
- Call Azure OpenAI GPT-4o
- Parse citations and format response
- Apply content safety filters

**Key RAG Parameters**:
- `top`: Number of documents to retrieve (default: 5)
- `temperature`: LLM creativity (default: 0.6)
- `response_length`: Max tokens (default: 2048)
- `semantic_ranker`: Enable semantic reranking
- `selected_folders`: RBAC folder filtering
- `selected_tags`: Tag-based filtering

#### 3. **RBAC System** (`shared_code/utility_rbck.py`)

**Core Concepts**:
- **Groups**: Azure AD security groups
- **Containers**: Blob storage containers (document repos)
- **Indexes**: Azure AI Search indexes
- **Roles**: Admin, Contributor, Reader

**Key Functions**:
```python
get_rbac_grplist_from_client_principle(request)  # Extract user's groups
find_container_and_role(group_list)              # Get accessible containers
find_index_and_role(group_list)                  # Get searchable indexes
find_upload_container_and_role(group_list)       # Upload permissions
```

**Cache Strategy**: Group mappings cached in memory with TTL to reduce Cosmos DB lookups.

#### 4. **Session Management** (`routers/sessions.py`)

**Cosmos DB Schema**:
```json
{
    "id": "<session_id>",
    "session_id": "<session_id>",
    "user_id": "<oid>",
    "title": "Chat title",
    "createdAt": "2026-02-07T...",
    "history": [
        {"user": "Question", "bot": "Answer"},
        ...
    ]
}
```

**Endpoints**:
- `GET /sessions/{user_id}` - List user's sessions
- `POST /sessions` - Create new session
- `GET /sessions/{session_id}` - Get session details
- `DELETE /sessions/{session_id}` - Delete session
- `PATCH /sessions/{session_id}` - Update session (rename)

#### 5. **Logging System** (`shared_code/status_log.py`)

**Status Classifications**:
```python
class StatusClassification(Enum):
    INFO = "Info"
    DEBUG = "Debug"
    ERROR = "Error"
```

**State Machine**:
```python
class State(Enum):
    UPLOADED = "UPLOADED"
    QUEUED = "QUEUED"
    PROCESSING = "PROCESSING"
    INDEXING = "INDEXING"
    COMPLETE = "COMPLETE"
    ERROR = "ERROR"
    THROTTLED = "THROTTLED"
    SKIPPED = "SKIPPED"
    DELETING = "DELETING"
    DELETED = "DELETED"
```

**Storage**: Cosmos DB with document-level status tracking.

---

## Deployment Configuration

### Sandbox Environment (Current)

**Resource Group**: `EsDAICoE-Sandbox`  
**Subscription**: `EsDAICoESub` (d2d4e571-e0f2-4f6c-901a-f88f7669bcba)

### Azure Resources

| Resource | Name | Type | Purpose |
|----------|------|------|---------|
| **Backend App** | `marco-sandbox-backend` | App Service | Combined frontend+backend |
| **Enrichment App** | `marco-sandbox-enrichment` | App Service | Document processing |
| **Functions App** | `marco-sandbox-func` | Function App | Pipeline orchestration |
| **OpenAI** | `marco-sandbox-openai` | Cognitive Services (OpenAI) | GPT-4o, embeddings |
| **Foundry** | `marco-sandbox-foundry` | AI Services | Azure AI Foundry Hub |
| **Search** | `marco-sandbox-search` | Azure AI Search | Hybrid index: `evajp-hybrid-index` |
| **Cosmos DB** | `marco-sandbox-cosmos` | Cosmos DB | Sessions, logs, RBAC cache |
| **Storage** | `marcosand20260203` | Storage Account | Document storage |
| **Key Vault** | `marcosandkv20260203` | Key Vault | Secrets management |
| **Container Registry** | `marcosandacr20260203` | ACR | Docker images |
| **API Management** | `marco-sandbox-apim` | APIM | API gateway (future) |
| **App Insights** | `marco-sandbox-appinsights` | Application Insights | Monitoring |

### Deployed AI Models (Foundry)

| Model | Deployment | Purpose | TPM |
|-------|-----------|---------|-----|
| **gpt-4o** | Primary | Complex reasoning, RAG | 20K |
| **gpt-4o-mini** | Cost-optimized | Simple queries | 50K |
| **text-embedding-ada-002** | Embeddings | Vector search | 100K |

**Endpoint**: `https://marco-sandbox-foundry.cognitiveservices.azure.com/`

### Container Build & Deployment

**Dockerfile Location**: `container_images/webapp_container_image/Dockerfile`

**Build Process**:
1. Frontend build (Vite): `npm run build` → `app/backend/static/`
2. Backend package: Python + dependencies
3. Container build: Azure Container Registry
4. Deploy: App Service pulls from ACR

**Container Registry**:
```bash
# Build command pattern
az acr build \
    --registry marcosandacr20260203 \
    --image webapp:$(date +%Y%m%d-%H%M%S)-complete \
    --file container_images/webapp_container_image/Dockerfile \
    .
```

**Recent Builds** (from terminal history):
- `webapp:20260207-*-complete` - Full frontend+backend
- `webapp:20260207-*-hybrid-fixed` - Authentication fixes
- `webapp:20260207-*-testuser-fix` - Test user support

### App Service Configuration

**App Settings** (76 settings applied):
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_SEARCH_SERVICE`
- `AZURE_SEARCH_INDEX=evajp-hybrid-index`
- `AZURE_COSMOSDB_ENDPOINT`
- `AZURE_STORAGE_ACCOUNT`
- `KEY_VAULT_URI`
- Feature flags (ENABLE_WEB_CHAT, ENABLE_UNGROUNDED_CHAT, etc.)

**Managed Identities** (3 enabled):
- System-assigned identity for App Service
- Identities for Functions and Enrichment apps

**RBAC Permissions** (15+ granted):
- Key Vault Secrets User
- Storage Blob Data Contributor
- Cognitive Services OpenAI User
- Search Index Data Reader
- Cosmos DB Account Reader

---

## Development Standards

### Production Code Quality Requirements

From [README.md](C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2\README.md):

✅ **World-class Enterprise and Government standards**  
✅ **Modular, minimally intrusive changes**  
✅ **Azure best practices (Well-Architected Framework)**  
✅ **Backward-compatible, stable in production**

### Testing Requirements

1. **Pre-flight tests**: Dry-run capabilities, validation checks
2. **Comprehensive testing**: Unit, integration, functional tests
3. **Test reproducibility**: Documented commands and procedures
4. **Evidence collection**: Logs, outputs, test reports

### Documentation Requirements

1. **Full feature documentation**: Enables reproduction by other engineers
2. **Inline code comments**: Complex logic and business rules
3. **README updates**: User-facing changes
4. **Test commands**: All procedures documented

### Development Workflow

```
1. Feature branch: feature/<name> or fix/<name>
2. Development + testing
3. Pull Request with:
   - Clear goals and design decisions
   - Summary of changes
   - Risk assessment
   - Test coverage + evidence
   - Reproducible test commands
4. Code review
5. Merge to main
6. Deploy to production
```

### Azure Best Practices Compliance

- ✅ Managed identities (no keys in code)
- ✅ Azure Key Vault for secrets
- ✅ Diagnostic logging enabled
- ✅ Error handling + retry logic
- ✅ Resource tagging for governance
- ✅ Least-privilege RBAC
- ✅ Content filtering (Azure OpenAI)

### Secure Mode Requirements

- ✅ Network isolation
- ✅ ESDC security compliance
- ✅ Content safety guardrails
- ✅ No PII in logs
- ✅ IT-SG333 compliance

---

## Key Integration Points

### 1. **Frontend ↔ Backend Communication**

**Protocol**: HTTP REST API (proxied in dev, direct in prod)  
**Format**: JSON  
**Key Flows**:
- Chat: Streaming NDJSON via `/chat`
- Session management: CRUD via `/sessions/*`
- Document operations: Upload status, delete, resubmit
- Authentication: Headers passed from App Service auth

### 2. **Backend ↔ Azure OpenAI**

**SDK**: OpenAI Python SDK with Azure AD auth  
**Pattern**:
```python
import openai
openai.api_type = "azure_ad"
openai.azure_ad_token_provider = token_provider

response = openai.ChatCompletion.create(
    engine="gpt-4o",
    messages=[...],
    temperature=0.6,
    max_tokens=2048
)
```

**Content Filtering**: Applied automatically by Azure OpenAI service (harm categories: violence, hate, sexual, self-harm).

### 3. **Backend ↔ Azure AI Search**

**SDK**: `azure.search.documents.SearchClient`  
**Index**: `evajp-hybrid-index` (hybrid: vector + keyword)  
**Query Pattern**:
```python
search_client = SearchClient(
    endpoint=AZURE_SEARCH_ENDPOINT,
    index_name="evajp-hybrid-index",
    credential=AZURE_CREDENTIAL
)

results = search_client.search(
    search_text=query,
    top=5,
    semantic_configuration_name="default",
    query_type="semantic",
    filter=filter_expr  # RBAC folder/tag filtering
)
```

### 4. **Backend ↔ Cosmos DB**

**SDK**: `azure.cosmos.CosmosClient`  
**Databases**:
- Sessions database: Chat history persistence
- Logs database: Document processing status
- RBAC cache: Group mappings (in-memory + Cosmos fallback)

**Pattern**:
```python
cosmos_client = CosmosClient(
    url=AZURE_COSMOSDB_ENDPOINT,
    credential=AZURE_CREDENTIAL
)
database = cosmos_client.get_database_client("sessions")
container = database.get_container_client("user_sessions")
```

### 5. **Backend ↔ Blob Storage**

**SDK**: `azure.storage.blob.BlobServiceClient`  
**Containers**:
- Document storage: RBAC-isolated per group
- Upload containers: Temporary staging
- Logs: Application telemetry

**SAS Token Generation**:
```python
blob_service_client = BlobServiceClient(
    account_url=AZURE_STORAGE_ACCOUNT,
    credential=AZURE_CREDENTIAL
)
sas_token = generate_blob_sas(
    account_name=ACCOUNT_NAME,
    container_name=CONTAINER_NAME,
    blob_name=BLOB_NAME,
    permission=BlobSasPermissions(read=True),
    expiry=datetime.utcnow() + timedelta(hours=1)
)
```

### 6. **RBAC Enforcement Flow**

```
1. User authenticates → Azure AD
2. App Service reads x-ms-client-principal header
3. Backend extracts Azure AD group IDs
4. Lookup group → container/index mappings (Cosmos DB)
5. Apply filters to:
   - Blob storage queries (container isolation)
   - Azure AI Search queries (filter expression)
   - Upload permissions (write access)
6. Return only authorized results
```

---

## EVA Brain Decomposition Notes

### Monolithic Coupling Points

**Current issues for decomposition**:

1. **Frontend build into backend** (`vite.config.ts`):
   ```typescript
   build: {
       outDir: "../backend/static"  // ❌ Tight coupling
   }
   ```

2. **Single container deployment**:
   - Dockerfile builds frontend + backend together
   - Cannot scale independently
   - Cannot deploy UI updates without backend restart

3. **Session management mixed with RAG logic** (`app.py`):
   - 2344 lines in single file
   - Sessions, chat, documents, RBAC all intertwined

4. **RBAC logic duplicated**:
   - Authorization checks in every endpoint
   - Should be extracted to middleware/gateway

### Recommended Decomposition Strategy

**Phase 1: Extract EVA Face** (API Gateway)
- Move all `/chat`, `/ask`, `/sessions` to standalone FastAPI service
- Implement as thin facade over EVA Brain
- RBAC enforcement at gateway
- Authentication layer at gateway

**Phase 2: Extract EVA Brain** (Intelligence Layer)
- Pure RAG engine: query → context → prompt → LLM → response
- No session management (stateless)
- No RBAC (trusts EVA Face)
- Scales independently

**Phase 3: Extract EVA Pipeline** (already separate)
- `app/enrichment/` → standalone service
- `functions/` → Azure Functions or container

**Phase 4: Frontend Independence**
- Build to separate hosting (Azure Static Web Apps)
- API calls to EVA Face URL (config-driven)
- Enable multiple UIs (browser extension, legacy clients)

### Critical Migration Considerations

1. **Session state**: Move from Cosmos DB in backend to EVA Face
2. **RBAC caching**: Centralize in EVA Face or Redis
3. **Citation lookup**: Maintain compatibility during transition
4. **Streaming responses**: Preserve WebSocket/SSE patterns
5. **Feature flags**: Centralized configuration service

---

## Appendix: File Locations

### Key Files for EVA Brain Knowledge Transfer

**Frontend**:
- Entry: `app/frontend/src/index.tsx`
- Main chat: `app/frontend/src/pages/chat/Chat.tsx`
- API layer: `app/frontend/src/api/api.ts`, `app/frontend/src/api/models.ts`
- Config: `app/frontend/vite.config.ts`, `app/frontend/package.json`

**Backend**:
- Main app: `app/backend/app.py`
- RAG approaches: `app/backend/approaches/*.py`
- RBAC: `app/backend/shared_code/utility_rbck.py`
- Sessions: `app/backend/routers/sessions.py`

**Infrastructure**:
- Dockerfile: `container_images/webapp_container_image/Dockerfile`
- Deployment scripts: `scripts/*.sh`, `Makefile`
- Terraform: `infra/main.tf`, `infra/core/*.tf`

**Documentation**:
- Main README: `README.md`
- Deployment guide: `docs/deployment/deployment.md`
- Features: `docs/features/features.md`
- Copilot instructions: `.github/copilot-instructions.md`

---

## Document Status

**Created**: February 7, 2026  
**Last Updated**: February 7, 2026  
**Analysis**: Comprehensive architectural review completed  
**Next Steps**: Use as baseline for EVA Brain decomposition planning

**Contact**: AICoE Development Team  
**Project Repository**: `C:\AICOE\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2`  
**EVA Brain Repository**: `C:\AICOE\eva-foundation\24-eva-brain`
