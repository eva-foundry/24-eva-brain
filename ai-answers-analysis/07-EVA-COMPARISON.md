# EVA vs AI Answers - Architectural Comparison

**Purpose:** Side-by-side comparison highlighting gaps and opportunities

---

## High-Level Architecture

### Current EVA Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User (Browser)                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                Frontend (React + Vite)                      │
│  • Chat interface                                           │
│  • Authentication (Azure AD)                                │
│  • Document upload                                          │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP POST /api/conversation
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Backend (Python + Quart)                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Sequential Request Handler                          │  │
│  │                                                      │  │
│  │  1. Receive request                                 │  │
│  │  2. Extract user context (OID, roles)              │  │
│  │  3. Build conversation history                      │  │
│  │  4. Generate search query                           │  │
│  │  5. Query Azure AI Search                           │  │
│  │  6. Retrieve document chunks                        │  │
│  │  7. Build prompt with chunks                        │  │
│  │  8. Call Azure OpenAI                               │  │
│  │  9. Stream response                                 │  │
│  │  10. Log to Cosmos DB                               │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Azure Infrastructure                           │
│  • Azure AI Search (vectors + keyword)                     │
│  • Azure OpenAI (GPT-4)                                     │
│  • Azure Cosmos DB (conversation logs)                     │
│  • Azure Blob Storage (documents)                          │
│  • Azure Functions (enrichment)                            │
└─────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- ✅ Simple, straightforward flow
- ✅ Well-integrated with Azure services
- ✅ Good authentication and security
- ❌ No state machine orchestration
- ❌ No tool usage (agent-based)
- ❌ No URL verification
- ❌ No short-circuit optimization
- ❌ Basic error handling
- ❌ Limited evaluation system

---

### AI Answers Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User (Browser)                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│             Frontend (React + Canada.ca Design)             │
│  • SSE streaming (real-time status)                        │
│  • Accessibility features                                   │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP POST /api/chat/chat-graph-run
                         ▼
┌─────────────────────────────────────────────────────────────┐
│               Backend (Node.js + Express)                   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │     LangGraph State Machine (9 Steps)               │  │
│  │                                                      │  │
│  │  1. init → Set up timing                           │  │
│  │  2. validate → Short query check (programmatic)    │  │
│  │  3. redact → PI detection (2-stage)                │  │
│  │  4. translate → Language detection (AI)            │  │
│  │  5. shortCircuit → Similar answer (vector + AI)    │  │
│  │     ├─ Match? → Skip to step 8                     │  │
│  │     └─ No? → Continue to step 6                    │  │
│  │  6. contextNode → Search + dept matching (AI)      │  │
│  │  7. answerNode → Generate with tools (AI + tools)  │  │
│  │  8. verifyNode → URL validation (programmatic)     │  │
│  │  9. persistNode → Save + evaluate (DB + AI)        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Agentic Tools (Autonomous)                  │  │
│  │  • downloadWebPage                                   │  │
│  │  • checkUrlStatus                                    │  │
│  │  • contextAgentTool                                  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                AWS Infrastructure                           │
│  • DocumentDB (MongoDB-compatible)                          │
│  • Azure OpenAI / OpenAI / Anthropic                       │
│  • Canada.ca Search / Google Search                        │
│  • Atlas Vector Search                                     │
└─────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- ✅ LangGraph state machine orchestration
- ✅ Autonomous tool usage
- ✅ Two-stage privacy protection
- ✅ Short-circuit optimization
- ✅ URL verification
- ✅ Real-time status updates
- ✅ Continuous evaluation
- ✅ Department-specific scenarios
- ✅ Context reuse
- ❌ Different infrastructure (AWS vs Azure)
- ❌ Different language (Node.js vs Python)

---

## Feature-by-Feature Comparison

### 1. Request Processing

| Feature | EVA | AI Answers | Gap Impact |
|---------|-----|------------|------------|
| **Orchestration** | Sequential functions | LangGraph state machine | 🟡 **MEDIUM** - Harder to maintain |
| **State management** | Mutable request object | Immutable state graph | 🟡 **MEDIUM** - Side effects possible |
| **Error handling** | Try/catch blocks | Node-level + conditional edges | 🟡 **MEDIUM** - Less robust |
| **Execution tracing** | Basic logging | Complete graph execution logs | 🟢 **LOW** - Harder debugging |
| **Status updates** | Single response | Real-time SSE streaming | 🟢 **LOW** - UX improvement |

**EVA Current:**
```python
# app/backend/app.py
@app.route("/api/conversation", methods=["POST"])
async def conversation():
    request_json = await request.get_json()
    
    # Sequential processing
    history = get_conversation_history(request_json)
    search_query = generate_search_query(request_json["messages"][-1])
    search_results = await azure_search_client.search(search_query)
    
    prompt = build_prompt(request_json["messages"], search_results)
    response = await openai_client.chat.completions.create(prompt)
    
    await log_conversation(request_json, response)
    return response
```

**AI Answers Equivalent:**
```javascript
// api/chat/chat-graph-run.js
app.post("/api/chat/chat-graph-run", async (req, res) => {
  const graph = graphRegistry.get('DefaultWithVectorGraph');
  
  // Stream status updates
  const stream = graph.stream(req.body);
  
  for await (const update of stream) {
    // Send SSE status: moderatingQuestion, buildingContext, etc.
    res.write(`data: ${JSON.stringify(update)}\n\n`);
  }
  
  res.end();
});
```

**Recommendation:** 🟡 **Medium Priority**
- LangGraph provides better structure but requires refactoring
- Consider for next major version
- Immediate benefit: clearer code organization

---

### 2. Privacy & Security

| Feature | EVA | AI Answers | Gap Impact |
|---------|-----|------------|------------|
| **PI detection** | Basic input validation | Two-stage (pattern + AI) | 🔴 **HIGH** - Risk exposure |
| **Question blocking** | None | Automatic before processing | 🔴 **HIGH** - PI may be logged |
| **Pattern matching** | Limited | Comprehensive (phone, email, SIN, address) | 🔴 **HIGH** - False negatives |
| **AI detection** | None | GPT-4 Mini for names, IDs | 🟡 **MEDIUM** - Catches edge cases |
| **Redaction** | None | Shows what was detected (XXX) | 🟢 **LOW** - User awareness |

**EVA Current:**
```python
# app/backend/approaches/chatreadretrieveread.py
# No dedicated PI detection before processing
def run(self, history, overrides):
    # Request processed immediately
    ...
```

**AI Answers Equivalent:**
```javascript
// agents/graphs/services/redactionService.js
class RedactionService {
  detectPII(text) {
    // Stage 1: Pattern-based (instant)
    const patterns = {
      phone: /\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/g,
      email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
      sin: /\b\d{9}\b/g,
      // ... more patterns
    };
    
    if (matchesAny(patterns, text)) {
      throw new RedactionError({
        reason: 'pattern_detected',
        redacted: redactMatches(text, patterns)
      });
    }
    
    // Stage 2: AI-powered (catches what Stage 1 missed)
    const aiDetection = await PIIAgentService.detect(text);
    if (aiDetection.hasPII) {
      throw new RedactionError({
        reason: 'ai_detected',
        types: aiDetection.types
      });
    }
  }
}
```

**Recommendation:** 🔴 **High Priority**
- Implement Stage 1 immediately (1-2 days)
- Add Stage 2 for production (1 week)
- Critical for secrecy mode

**EVA Implementation:**
```python
# app/backend/security/pi_detection.py
import re
from typing import Dict, List

class PIDetectionService:
    """Two-stage PI detection for EVA"""
    
    PATTERNS = {
        'phone': r'\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b',
        'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        'sin': r'\b\d{9}\b',
        'postal_code': r'\b[A-Z]\d[A-Z]\s?\d[A-Z]\d\b',
        'case_number': r'\b(file|case)\s*(no|number)?\.?\s*\d{4,}\b',
        # More patterns...
    }
    
    def detect_stage1(self, text: str) -> Dict:
        """Fast pattern-based detection"""
        detected = []
        redacted_text = text
        
        for name, pattern in self.PATTERNS.items():
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                detected.append(name)
                redacted_text = re.sub(pattern, 'XXX', redacted_text, flags=re.IGNORECASE)
        
        return {
            'has_pi': len(detected) > 0,
            'detected_types': detected,
            'redacted_text': redacted_text
        }
    
    async def detect_stage2(self, text: str) -> Dict:
        """AI-powered detection for edge cases"""
        # Use GPT-4 Mini to detect names, personal info
        # (Implementation similar to AI Answers)
        ...

# Use in request handler
@app.route("/api/conversation", methods=["POST"])
async def conversation():
    request_json = await request.get_json()
    message = request_json["messages"][-1]["content"]
    
    # STAGE 1: Fast pattern check
    stage1 = pi_detection.detect_stage1(message)
    if stage1['has_pi']:
        return jsonify({
            'error': 'personal_information_detected',
            'types': stage1['detected_types'],
            'redacted': stage1['redacted_text']
        }), 400
    
    # STAGE 2: AI check (for production)
    stage2 = await pi_detection.detect_stage2(message)
    if stage2['has_pi']:
        return jsonify({
            'error': 'personal_information_detected',
            'types': stage2['detected_types']
        }), 400
    
    # Continue processing...
```

---

### 3. Tool Usage / Agent Capabilities

| Feature | EVA | AI Answers | Gap Impact |
|---------|-----|------------|------------|
| **Autonomous tools** | None | downloadWebPage, checkUrl, context | 🔴 **HIGH** - No verification |
| **Web scraping** | None | Downloads current pages | 🔴 **HIGH** - Outdated info |
| **URL validation** | None | Validates before citing | 🔴 **HIGH** - Broken citations |
| **Context re-derivation** | None | AI can re-query if needed | 🟡 **MEDIUM** - Stuck with bad context |
| **Tool tracking** | N/A | Complete tool usage logs | 🟢 **LOW** - Debugging benefit |

**EVA Current:**
```python
# No tools - only predefined search
async def search_and_answer(query):
    # Search Azure AI Search
    results = await search_client.search(query)
    
    # Use whatever chunks returned
    # No verification, no downloads, no validation
    answer = await llm.generate(query, results)
    return answer
```

**AI Answers Equivalent:**
```javascript
// AI autonomously uses tools during answer generation
const agent = createReactAgent({
  llm,
  tools: [downloadWebPageTool, checkUrlStatusTool, contextAgentTool],
  prompt: systemPrompt
});

// AI decides: "This URL is from 2025, I should download it"
const result = await agent.invoke({
  question: "What are the tax brackets for 2025?",
  context: {
    urls: ["https://www.cra.gc.ca/tax-brackets-2025.html"]
  }
});

// AI automatically:
// 1. Downloads CRA page
// 2. Parses current content
// 3. Generates answer with verified info
// 4. Validates citation URL
// 5. Returns answer
```

**Recommendation:** 🔴 **High Priority**
- Implement basic web scraping (1 week)
- Add URL validation (2-3 days)
- Critical for legal accuracy

**EVA Implementation:**
```python
# app/backend/tools/web_scraper.py
from langchain.tools import tool
import requests
from bs4 import BeautifulSoup

@tool
def download_case_law(url: str) -> str:
    """
    Download current case law or legislation for verification.
    
    Critical for ensuring EVA has current legal information.
    """
    response = requests.get(url, timeout=10)
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # Extract main content (case text, legislation)
    main_content = soup.find('main') or soup.find('article')
    
    # Convert to clean text
    text = main_content.get_text(separator='\n', strip=True)
    
    return text

@tool
def validate_citation_url(url: str) -> dict:
    """
    Validate that a case law citation is accessible.
    
    Prevents returning broken CanLII or court links.
    """
    try:
        response = requests.head(url, timeout=5, allow_redirects=True)
        return {
            'valid': response.status_code < 400,
            'status': response.status_code
        }
    except:
        return {'valid': False, 'status': 0}

# Create agent with tools
from langgraph.prebuilt import create_react_agent
from langchain_openai import AzureChatOpenAI

llm = AzureChatOpenAI(...)
tools = [download_case_law, validate_citation_url]

agent = create_react_agent(llm, tools)
```

---

### 4. Performance Optimization

| Feature | EVA | AI Answers | Gap Impact |
|---------|-----|------------|------------|
| **Short-circuit** | None | Vector similarity reuse | 🟡 **MEDIUM** - 60-80% slower |
| **Context reuse** | None | Reuses valid context | 🟡 **MEDIUM** - Redundant searches |
| **Prompt caching** | None | LangChain caching | 🟢 **LOW** - Cost savings |
| **Conditional skipping** | No | Skips steps when possible | 🟡 **MEDIUM** - Wasted cycles |

**Performance Comparison:**

```
EVA (Every Question):
1. Extract context: ~100ms
2. Generate search query: ~500ms (AI)
3. Azure AI Search: ~800ms
4. Build prompt: ~50ms
5. Generate answer: ~5,000ms (AI)
6. Log: ~200ms
Total: ~6,650ms

AI Answers (With Short-Circuit, 60% hit rate):
Cached Questions (60%):
1. Vector search: ~100ms
2. Verify URL: ~200ms
Total: ~300ms (22x faster)

New Questions (40%):
1-9. Full pipeline: ~8,000ms
Total: ~8,000ms

Weighted Average: (0.6 × 300) + (0.4 × 8,000) = 3,380ms
Overall: 2x faster, 70% cost reduction
```

**Recommendation:** 🟡 **Medium Priority**
- High ROI for user experience
- Implementation: 3-5 days
- Requires vector embedding setup

**EVA Implementation:**
```python
# app/backend/optimization/short_circuit.py
from langchain.embeddings import AzureOpenAIEmbeddings
from azure.cosmos import CosmosClient

class ShortCircuitService:
    """Reuse previous answers for similar questions"""
    
    def __init__(self):
        self.embeddings = AzureOpenAIEmbeddings(...)
        self.cosmos = CosmosClient(...)
    
    async def find_similar_answer(self, question: str, threshold: float = 0.85):
        """Search for previously answered similar question"""
        # Generate embedding
        question_embedding = await self.embeddings.aembed_query(question)
        
        # Cosmos DB vector search
        results = self.cosmos.vector_search(
            embedding=question_embedding,
            limit=5,
            score_threshold=threshold
        )
        
        if not results:
            return None
        
        # Verify top match is recent and valid
        top_match = results[0]
        if top_match['score'] >= threshold:
            # Validate citation URL still works
            if self.validate_url(top_match['citation_url']):
                return {
                    'answer': top_match['answer'],
                    'citation_url': top_match['citation_url'],
                    'similarity_score': top_match['score'],
                    'original_date': top_match['created_at']
                }
        
        return None

# Use in handler
@app.route("/api/conversation", methods=["POST"])
async def conversation():
    message = request_json["messages"][-1]["content"]
    
    # Check for similar previous answer
    cached = await short_circuit.find_similar_answer(message)
    if cached:
        logger.info(f"Short-circuit hit (score: {cached['similarity_score']})")
        return jsonify({
            'answer': cached['answer'],
            'citation': cached['citation_url'],
            'cached': True
        })
    
    # No match, proceed with full pipeline
    ...
```

---

### 5. Citation Management

| Feature | EVA | AI Answers | Gap Impact |
|---------|-----|------------|------------|
| **URL validation** | None | Programmatic check before return | 🔴 **HIGH** - Broken links |
| **Fallback handling** | None | Auto-fallback if invalid | 🔴 **HIGH** - Dead ends |
| **Citation format** | AI-generated | AI + verification | 🟡 **MEDIUM** - Inconsistent |
| **Source tracking** | Basic | Complete provenance | 🟢 **LOW** - Audit trail |

**EVA Current:**
```python
# AI generates citation, returned as-is
answer = """
Based on the Federal Courts Rules...
[Citation: https://laws.justice.gc.ca/eng/regulations/SOR-..."]
"""
# No check if URL works!
```

**AI Answers:**
```javascript
// Step 8: verifyNode
async verifyNode(state) {
  const citationUrl = state.answer.citationUrl;
  
  // Check if URL accessible
  const validation = await checkUrlStatus(citationUrl);
  
  if (!validation.isValid) {
    // URL broken, use fallback
    const fallback = state.context.departmentUrl || 
                     buildSearchUrl(state.userMessage);
    
    logger.warn(`Invalid citation: ${citationUrl}, using fallback`);
    return {
      finalCitationUrl: fallback,
      confidenceRating: 0  // Mark as low confidence
    };
  }
  
  return {
    finalCitationUrl: validation.finalUrl,  // May have redirected
    confidenceRating: state.answer.confidenceRating
  };
}
```

**Recommendation:** 🔴 **High Priority**
- Immediate implementation (1-2 days)
- Prevents broken CanLII/court links
- Critical for user trust

---

### 6. Evaluation & Quality

| Feature | EVA | AI Answers | Gap Impact |
|---------|-----|------------|------------|
| **Evaluation workflow** | Manual spot checks | Continuous human + AI | 🟡 **MEDIUM** - Quality drift |
| **Expert evaluation** | Ad-hoc | Structured admin interface | 🟡 **MEDIUM** - No baseline |
| **AI evaluation** | None | GPT-4 using expert data | 🟡 **MEDIUM** - No automation |
| **Feedback loop** | Limited | Feeds into prompts/scenarios | 🟡 **MEDIUM** - No improvement cycle |
| **Metrics tracking** | Basic usage | Detailed quality metrics | 🟢 **LOW** - Less visibility |

**AI Answers Evaluation:**
```javascript
// Human expert evaluates in admin UI
{
  question: "How do I apply for EI?",
  answer: "...",
  evaluation: {
    accuracy: 9/10,
    relevance: 10/10,
    completeness: 8/10,
    citation_quality: 9/10,
    notes: "Excellent answer, minor detail about seasonal workers could be added"
  }
}

// AI evaluator learns from expert evaluations
const aiEvaluation = await evaluatorAgent.evaluate({
  question,
  answer,
  expertExamples: getTopScoredExamples(10)
});

// Feedback loop: Low scores trigger scenario updates
if (aiEvaluation.accuracy < 7) {
  notifyContentTeam({
    question,
    issue: "Low accuracy detected",
    suggested_action: "Update department scenario"
  });
}
```

**Recommendation:** 🟡 **Medium Priority**
- Important but not urgent
- Focus on manual evaluation first
- Automate as volume grows

---

## Summary: Priority Matrix

### 🔴 HIGH PRIORITY (Immediate Implementation)

1. **URL Validation** (1-2 days)
   - Impact: Prevents broken citations
   - Complexity: Low
   - Files: `app/backend/utils/url_validator.py`

2. **Stage 1 PI Detection** (2-3 days)
   - Impact: Critical for secrecy mode
   - Complexity: Low
   - Files: `app/backend/security/pi_detection.py`

3. **Agentic Web Scraping** (1 week)
   - Impact: Ensures current legal information
   - Complexity: Medium
   - Files: `app/backend/tools/web_scraper.py`

### 🟡 MEDIUM PRIORITY (Next Sprint)

4. **Short-Circuit Optimization** (3-5 days)
   - Impact: 2x faster, 70% cost reduction
   - Complexity: Medium
   - Files: `app/backend/optimization/short_circuit.py`

5. **Stage 2 AI PI Detection** (1 week)
   - Impact: Catches edge cases
   - Complexity: Medium
   - Files: `app/backend/security/ai_pi_detection.py`

6. **Court-Specific Scenarios** (1 week)
   - Impact: Better answer quality per domain
   - Complexity: Medium
   - Files: `app/backend/prompts/court_scenarios/`

### 🟢 LOW PRIORITY (Future Iterations)

7. **LangGraph Migration** (2-3 weeks)
   - Impact: Better architecture
   - Complexity: High
   - Files: `app/backend/graph/` (new structure)

8. **Real-Time SSE Status** (1 week)
   - Impact: UX improvement
   - Complexity: Medium
   - Files: `app/backend/api/sse_handler.py`

9. **Continuous Evaluation** (3 weeks)
   - Impact: Automated quality monitoring
   - Complexity: High
   - Files: `app/backend/evaluation/`

---

**Next:** [08-INTEGRATION-PLAN.md](08-INTEGRATION-PLAN.md) for phased implementation roadmap.
