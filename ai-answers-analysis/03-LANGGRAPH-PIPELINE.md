# LangGraph Pipeline - Detailed Breakdown

**Reference:** `C:\AICOE\ai-answers\agents\graphs\DefaultWithVectorGraph.js`

---

## Pipeline Overview

AI Answers uses a **9-step LangGraph state machine** that processes every user question through validation, translation, context derivation, and answer generation stages.

```
User Question
     ↓
[1. init] ────────────→ Initialize state, start timer
     ↓
[2. validate] ────────→ Block short/meaningless queries
     ↓
[3. redact] ──────────→ Two-stage PI detection & blocking
     ↓
[4. translate] ───────→ Detect language, translate to English
     ↓
[5. shortCircuit] ────→ Check for similar previous answer
     ├─ Match found ──→ Skip to [8. verifyNode]
     └─ No match ─────→ Continue to [6. contextNode]
     ↓
[6. contextNode] ─────→ Query rewrite, search, dept matching
     ↓
[7. answerNode] ──────→ Generate answer with tools
     ↓
[8. verifyNode] ──────→ Validate citation URL
     ↓
[9. persistNode] ─────→ Save to database, trigger evaluation
     ↓
    END
```

---

## State Definition

The graph maintains **immutable state** passed between nodes:

```javascript
const GraphState = Annotation.Root({
  // Request context
  chatId: Annotation(),                // Unique chat session
  userMessage: Annotation(),           // Original question
  userMessageId: Annotation(),         // Message ID
  conversationHistory: Annotation(),   // Previous messages
  lang: Annotation(),                  // UI language (en/fr)
  department: Annotation(),            // Dept code (optional)
  referringUrl: Annotation(),          // Page URL
  selectedAI: Annotation(),            // AI provider
  searchProvider: Annotation(),        // Search provider
  
  // Processing state
  startTime: Annotation(),             // Pipeline start time
  redactedText: Annotation(),          // After PI removal
  translationData: Annotation(),       // Translation results
  cleanedHistory: Annotation(),        // Cleaned conv history
  context: Annotation(),               // Derived context
  usedExistingContext: Annotation(),   // Context reused?
  shortCircuitPayload: Annotation(),   // Similar answer found
  
  // Output state
  answer: Annotation(),                // Generated answer
  finalCitationUrl: Annotation(),      // Verified URL
  confidenceRating: Annotation(),      // 0-10 score
  status: Annotation(),                // Current status
  result: Annotation()                 // Final result object
});
```

**Key principle:** Each node can only modify specific fields, ensuring encapsulation and testability.

---

## Step-by-Step Breakdown

### 1. Initialization Node

**File:** `agents/graphs/DefaultWithVectorGraph.js:47-66`

**Purpose:** Set up timing and initial status

```javascript
graph.addNode('init', async (state) => {
  const startTime = Date.now();
  
  await ServerLoggingService.info('Starting DefaultWithVectorGraph', 
    state.chatId, {
      lang: state.lang,
      referringUrl: state.referringUrl,
      selectedAI: state.selectedAI,
    }
  );
  
  return { 
    startTime, 
    status: WorkflowStatus.MODERATING_QUESTION 
  };
});
```

**Output:**
- `startTime`: Timestamp for performance tracking
- `status`: `"moderatingQuestion"` (sent to client via SSE)

**EVA Application:**
```python
@workflow.node
async def init_node(state: GraphState) -> dict:
    """Initialize pipeline state"""
    return {
        "start_time": time.time(),
        "status": "moderating_question",
        "trace_id": str(uuid.uuid4())
    }
```

---

### 2. Validation Node (Short Query)

**File:** `agents/graphs/services/shortQuery.js`

**Purpose:** Block meaningless short queries

**Type:** Programmatic (no AI, instant)

```javascript
graph.addNode('validate', async (state) => {
  await workflow.validateShortQuery(
    state.conversationHistory,
    state.userMessage,
    state.lang,
    state.department
  );
  return {};
});
```

**Logic:**
```javascript
function validateShortQuery(history, message, lang, dept) {
  const wordCount = message.trim().split(/\s+/).length;
  
  // Check current message
  if (wordCount <= 2) {
    // Look for longer message in history
    const hasLongerPrevious = history.some(msg => 
      msg.content.split(/\s+/).length > 2
    );
    
    if (!hasLongerPrevious) {
      // Block: too short and no context
      throw new ShortQueryValidation(
        getFallbackUrl(lang, dept)
      );
    }
  }
}
```

**Error Handling:**
```javascript
// In main graph execution
try {
  const result = await workflow.compile().invoke(state);
} catch (error) {
  if (error instanceof ShortQueryValidation) {
    return {
      error: 'short_query',
      fallbackUrl: error.fallbackUrl,
      message: getLocalizedMessage(lang, 'tooShort')
    };
  }
  throw error;
}
```

**EVA Application:**
Short legal queries often need context:
- "How do I appeal?" ← Too vague, needs clarification
- "What's the deadline?" ← Which deadline? For what?
- "File form" ← Which form? Which court?

Validation prevents wasted AI calls on questions that need clarification anyway.

---

### 3. Redaction Node (PI Detection)

**File:** `agents/graphs/services/redactionService.js`

**Purpose:** Two-stage privacy protection

**Type:** Programmatic + AI

#### Stage 1: Pattern-Based Detection (No AI)

```javascript
class RedactionService {
  detectPII(text) {
    const patterns = {
      // Phone numbers
      phone: /\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/g,
      
      // Email addresses
      email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
      
      // 9-digit numbers (SIN candidates)
      nin: /\b\d{9}\b/g,
      
      // Addresses (simplified)
      address: /\b\d+\s+[A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd)\b/gi,
      
      // Profanity
      profanity: PROFANITY_PATTERNS,
      
      // Threats
      threats: THREAT_PATTERNS
    };
    
    let hasPII = false;
    let redactedText = text;
    
    for (const [type, pattern] of Object.entries(patterns)) {
      if (pattern.test(text)) {
        hasPII = true;
        // Mark with XXX to show user what was detected
        redactedText = redactedText.replace(pattern, 'XXX');
      }
    }
    
    return { hasPII, redactedText };
  }
}
```

#### Stage 2: AI-Powered Detection (GPT-4 Mini)

**File:** `services/PIIAgentService.js`

```javascript
async detectPIIWithAI(text, lang, chatId) {
  const prompt = buildPIIDetectionPrompt(text);
  
  const response = await this.agent.invoke([
    { role: 'system', content: PIIAgentPrompt[lang] },
    { role: 'user', content: prompt }
  ]);
  
  // Parse AI response
  const detected = parsePIIResponse(response.content);
  
  return {
    hasPII: detected.length > 0,
    detectedTypes: detected,  // ["person_name", "personal_id"]
    redactedText: redactText(text, detected)
  };
}
```

**Combined Flow:**
```javascript
graph.addNode('redact', async (state) => {
  // Stage 1: Fast pattern matching
  const stage1 = redactionService.detectPII(state.userMessage);
  
  if (stage1.hasPII) {
    throw new RedactionError({
      reason: 'pattern_detected',
      redactedText: stage1.redactedText
    });
  }
  
  // Stage 2: AI-powered detection
  const stage2 = await PIIAgentService.detectPIIWithAI(
    state.userMessage,
    state.lang,
    state.chatId
  );
  
  if (stage2.hasPII) {
    throw new RedactionError({
      reason: 'ai_detected',
      detectedTypes: stage2.detectedTypes,
      redactedText: stage2.redactedText
    });
  }
  
  return { redactedText: state.userMessage };
});
```

**EVA Application:**
Legal queries may contain:
```
❌ "My SIN is 123-456-789, am I eligible?"
❌ "John Smith v. Jane Doe - what happened?"
❌ "My address is 123 Main St, what forms?"
```

Two-stage blocking prevents these from:
- Being processed
- Being logged
- Reaching the database
- Being cached in vector store

Critical for secrecy mode in EVA.

---

### 4. Translation Node

**File:** `agents/graphs/services/translationService.js`

**Purpose:** Detect language and translate to English

**Type:** AI-powered (GPT-4 Mini)

```javascript
graph.addNode('translate', async (state) => {
  const translationData = await translationService.translate({
    text: state.redactedText,
    conversationHistory: state.cleanedHistory,
    targetLang: 'eng'
  });
  
  return { translationData };
});
```

**Translation Service:**
```javascript
async translate({ text, conversationHistory, targetLang }) {
  const prompt = `
Detect the language and translate to ${targetLang}.
Return JSON: { "originalLanguage": "xxx", "translatedText": "...", "noTranslation": false }

Conversation history for context:
${conversationHistory.slice(-3).map(m => `${m.role}: ${m.content}`).join('\n')}

Current message: ${text}
  `;
  
  const response = await agent.invoke(prompt);
  
  return JSON.parse(response.content);
}
```

**Output:**
```javascript
{
  originalLanguage: 'fra',        // ISO 639-3 code
  translatedLanguage: 'eng',
  translatedText: 'How do I apply for EI?',
  noTranslation: false            // true if already English
}
```

**Why translate to English?**
1. All context derivation done on English question
2. Department scenarios written in English
3. Search queries optimized for English
4. Admin evaluation team reads English
5. Answer translated back to user's language later

**EVA Application:**
Bilingual support for French/English queries in Canadian jurisprudence.
Could extend to other languages for international law queries.

---

### 5. Short-Circuit Node (Optimization)

**File:** `api/chat/chat-similar-answer.js`

**Purpose:** Detect and reuse previous similar answers

**Type:** Vector similarity + AI reranking

**This is where the magic happens:**

```javascript
graph.addNode('shortCircuit', async (state) => {
  // Skip if conversation already has AI replies (follow-up question)
  if (hasAIReplies(state.conversationHistory)) {
    return {};
  }
  
  // Generate embedding for current question
  const embedding = await EmbeddingService.generateEmbedding(
    state.translationData.translatedText
  );
  
  // Search vector store
  const candidates = await vectorStore.similaritySearch({
    embedding,
    limit: 10,
    scoreThreshold: 0.75
  });
  
  if (candidates.length === 0) {
    return {};
  }
  
  // Use AI to rerank candidates
  const match = await rerankerAgent.findBestMatch({
    question: state.translationData.translatedText,
    candidates
  });
  
  if (match && match.score >= SIMILARITY_THRESHOLD) {
    // Found match! Skip to verification
    return {
      shortCircuitPayload: {
        answer: match.answer,
        citationUrl: match.citationUrl,
        originalQuestionId: match.questionId,
        similarityScore: match.score
      }
    };
  }
  
  return {};
});
```

**Conditional Edge:**
```javascript
.addConditionalEdges('shortCircuit',
  (state) => {
    if (state.shortCircuitPayload) {
      return 'verifyNode';  // Skip context and answer generation
    }
    return 'contextNode';   // Continue normal flow
  },
  {
    verifyNode: 'verifyNode',
    contextNode: 'contextNode'
  }
);
```

**Reranker Agent:**
```javascript
// agents/prompts/rerankerPrompt.js
const RERANKER_PROMPT = `
You are an expert at determining if two questions are asking the same thing.

Original question: {question}

Candidate previous answers:
{candidates}

For each candidate, rate 0-10 how well it matches the original question.
Consider:
- Same intent and topic
- Answer would be appropriate
- Similar specificity level

Return JSON array: [{ "id": 1, "score": 8.5, "reasoning": "..." }, ...]
`;
```

**Performance Impact:**
```
Without short-circuit (every question):
- Context derivation: ~2-3 seconds
- Answer generation: ~5-8 seconds
- Total: ~8-12 seconds

With short-circuit (60% hit rate):
- Vector search: ~0.1 seconds
- Reranking: ~0.5 seconds  
- Verification: ~0.2 seconds
- Total: ~1 second

Speed improvement: 8-12x faster
Cost reduction: 70-90% (skips multiple AI calls)
```

**EVA Application:**
Legal queries are often repeated:
```
"How do I appeal a tax court decision?"
"What's the process to appeal CRA decision?"
"Appeal process for tax matters?"
```

All three should get same answer. Short-circuit ensures:
- Consistent responses
- Fast delivery
- Cost efficiency
- Still validates citation URL (safety)

---

### 6. Context Derivation Node

**File:** `agents/graphs/services/contextService.js`

**Purpose:** Multi-step context building

**Type:** AI-powered (multiple stages)

**Only runs if short-circuit found no match**

#### Sub-Step 6a: Query Rewrite

```javascript
const queryRewriteAgent = await AgentFactory.create({
  type: 'queryRewrite',
  model: 'gpt-4-mini'
});

const rewrittenQuery = await queryRewriteAgent.invoke([
  { role: 'system', content: QUERY_REWRITE_PROMPT },
  { role: 'user', content: JSON.stringify({
      question: state.translationData.translatedText,
      history: state.cleanedHistory.slice(-2)
    })
  }
]);
```

**Query Rewrite Prompt:**
```javascript
// agents/prompts/queryRewriteAgentPrompt.js
export const QUERY_REWRITE_PROMPT = `
You are an expert at crafting search queries for Government of Canada content.

Given a user question and conversation history, create an optimized search query that will find the most relevant government pages.

Rules:
- 3-7 words optimal
- Include key terms from question
- Add context from history if follow-up
- Use official terminology
- No quotes or operators

Examples:
Q: "How do I apply for employment insurance benefits?"
Search: employment insurance EI application process

Q: "What documents do I need?"  (prev: "applying for passport")
Search: passport application required documents

Return ONLY the search query, nothing else.
`;
```

#### Sub-Step 6b: Search Execution

```javascript
let searchResults;

if (state.searchProvider === 'canadaCa') {
  searchResults = await canadaCaSearch(rewrittenQuery);
} else {
  searchResults = await googleSearch(rewrittenQuery, {
    site: 'site:canada.ca OR site:gc.ca'
  });
}
```

**Search Result Format:**
```javascript
[
  {
    title: "Employment Insurance (EI) - Application",
    url: "https://www.canada.ca/en/services/benefits/ei/ei-apply.html",
    snippet: "Learn how to apply for EI benefits online...",
    relevance: 0.92
  },
  // ... more results
]
```

#### Sub-Step 6c: Department Matching

```javascript
const contextAgent = await AgentFactory.create({
  type: 'context',
  model: 'gpt-4-mini'
});

const context = await contextAgent.invoke([
  { role: 'system', content: CONTEXT_SYSTEM_PROMPT },
  { role: 'user', content: JSON.stringify({
      question: state.translationData.translatedText,
      searchResults,
      referringUrl: state.referringUrl
    })
  }
]);
```

**Context Agent Output:**
```javascript
{
  department: 'ESDC-EDSC',  // Employment & Social Development Canada
  departmentUrl: 'https://www.canada.ca/en/employment-social-development.html',
  topic: 'Employment Insurance application',
  relevantUrls: [
    'https://www.canada.ca/en/services/benefits/ei/ei-apply.html',
    'https://www.canada.ca/en/services/benefits/ei/ei-regular-benefit.html'
  ],
  confidence: 0.95
}
```

#### Sub-Step 6d: Load Department Scenarios

```javascript
// Check if department has custom scenarios
const scenarioPath = `agents/prompts/scenarios/context-${context.department}`;

let departmentScenarios = null;
if (fs.existsSync(`${scenarioPath}/scenarios.md`)) {
  departmentScenarios = {
    updates: fs.readFileSync(`${scenarioPath}/updates.md`, 'utf8'),
    scenarios: fs.readFileSync(`${scenarioPath}/scenarios.md`, 'utf8')
  };
}
```

**Node Return:**
```javascript
return {
  context: {
    queryRewritten: rewrittenQuery,
    department: context.department,
    departmentUrl: context.departmentUrl,
    topic: context.topic,
    searchResults: context.relevantUrls,
    departmentScenarios
  },
  status: WorkflowStatus.GENERATING_ANSWER
};
```

**EVA Application:**
Replace "department" with "court/jurisdiction":
```javascript
{
  jurisdiction: 'FCA',  // Federal Court of Appeal
  jurisdictionUrl: 'https://decisions.fca-caf.gc.ca/',
  topic: 'Civil appeal procedure',
  relevantUrls: [
    'https://laws.justice.gc.ca/eng/regulations/SOR-98-106/',
    'https://www.fca-caf.gc.ca/en/pages/practice-and-procedure'
  ],
  courtScenarios: {
    updates: '... recent rule changes ...',
    scenarios: '... common appeal patterns ...'
  }
}
```

---

## Continue reading in next file...

**Next:** [04-AGENTIC-TOOLS.md](04-AGENTIC-TOOLS.md) for Step 7 (Answer Generation with Tools), Step 8 (Verification), and Step 9 (Persistence).
