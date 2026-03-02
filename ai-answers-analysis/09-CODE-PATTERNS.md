# Quick Reference - Code Patterns & Templates

**Purpose:** Ready-to-use code patterns extracted from AI Answers for EVA implementation

---

## Pattern 1: URL Validation with Fallback

### AI Answers Implementation
```javascript
// agents/graphs/services/verifyNode.js
async function verifyNode(state) {
  const citationUrl = state.answer.citationUrl;
  
  // Check if URL accessible
  const validation = await checkUrlStatus(citationUrl);
  
  if (!validation.isValid) {
    // Use fallback
    const fallback = state.context.departmentUrl || 
                     buildSearchUrl(state.userMessage);
    return {
      finalCitationUrl: fallback,
      confidenceRating: 0
    };
  }
  
  return {
    finalCitationUrl: validation.finalUrl,
    confidenceRating: state.answer.confidenceRating
  };
}
```

### EVA Python Implementation
```python
# app/backend/utils/citation_validator.py

import requests
from typing import Dict, Optional
import urllib.parse

class CitationValidator:
    """Validate and manage citation URLs"""
    
    def __init__(self, timeout: int = 5):
        self.timeout = timeout
        self.session = requests.Session()
        
    def validate(self, url: str) -> Dict:
        """Check if URL is accessible"""
        try:
            response = self.session.head(
                url, 
                timeout=self.timeout,
                allow_redirects=True
            )
            return {
                'valid': 200 <= response.status_code < 400,
                'status': response.status_code,
                'final_url': response.url
            }
        except Exception as e:
            return {'valid': False, 'error': str(e)}
    
    def get_fallback(self, original_url: str, query: str) -> str:
        """Generate fallback URL by jurisdiction"""
        
        jurisdiction_fallbacks = {
            'scc-csc.ca': 'https://www.scc-csc.ca/home-accueil/index-eng.aspx',
            'fca-caf.gc.ca': 'https://www.fca-caf.gc.ca/en',
            'canlii.org': f'https://www.canlii.org/en/#search/text={urllib.parse.quote(query)}',
            'laws.justice.gc.ca': 'https://laws.justice.gc.ca/eng/',
        }
        
        for domain, fallback in jurisdiction_fallbacks.items():
            if domain in original_url:
                return fallback
        
        # Default: CanLII search
        return f'https://www.canlii.org/en/#search/text={urllib.parse.quote(query)}'

# Usage in conversation handler
validator = CitationValidator()

citation_url = extract_citation(answer)
validation = validator.validate(citation_url)

if not validation['valid']:
    logger.warning(f"Invalid citation: {citation_url}")
    fallback = validator.get_fallback(citation_url, user_query)
    answer = answer.replace(citation_url, fallback)
```

---

## Pattern 2: Two-Stage PI Detection

### Complete Implementation
```python
# app/backend/security/pi_detector.py

import re
import json
from typing import Dict, List
from openai import AzureOpenAI

class PIDetector:
    """Two-stage personal information detection"""
    
    # Stage 1: Fast patterns (< 100ms)
    PATTERNS = {
        'phone': r'\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b',
        'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        'sin_ssn': r'\b\d{9}\b',
        'postal_code': r'\b[A-Z]\d[A-Z]\s?\d[A-Z]\d\b',
        'case_file': r'\b(file|case|docket)\s*#?\s*\d{4,}[-/]?\d*\b',
        'court_file': r'\b\d{2,4}-\d{4,6}\b',  # e.g., 23-12345
    }
    
    def __init__(self, ai_client: AzureOpenAI = None):
        self.ai_client = ai_client
    
    def stage1_detect(self, text: str) -> Dict:
        """Pattern-based detection (no AI cost)"""
        detected = []
        redacted = text
        
        for pi_type, pattern in self.PATTERNS.items():
            matches = list(re.finditer(pattern, text, re.IGNORECASE))
            if matches:
                detected.append({
                    'type': pi_type,
                    'count': len(matches),
                    'examples': [m.group() for m in matches[:2]]
                })
                redacted = re.sub(pattern, '[REDACTED]', redacted, flags=re.IGNORECASE)
        
        return {
            'has_pi': len(detected) > 0,
            'detected': detected,
            'redacted_text': redacted,
            'stage': 1
        }
    
    async def stage2_detect(self, text: str) -> Dict:
        """AI-powered detection for edge cases"""
        if not self.ai_client:
            return {'has_pi': False, 'stage': 2, 'skipped': True}
        
        prompt = f"""Analyze for personal information:

Text: {text}

Detect:
- Person names (first + last name together)
- Personal identifiers (health card, driver license, passport)
- Specific addresses or locations
- Sensitive case details that identify individuals

Output JSON only:
{{"has_pi": true/false, "types": ["person_name", ...], "confidence": 0-100}}"""
        
        response = await self.ai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": "Privacy expert. Output JSON only."},
                {"role": "user", "content": prompt}
            ],
            temperature=0,
            max_tokens=150
        )
        
        result = json.loads(response.choices[0].message.content)
        return {
            'has_pi': result['has_pi'],
            'detected': [{'type': t, 'confidence': result['confidence']} for t in result.get('types', [])],
            'stage': 2
        }
    
    async def detect(self, text: str, use_ai: bool = False) -> Dict:
        """Full two-stage detection"""
        # Always run Stage 1
        stage1 = self.stage1_detect(text)
        if stage1['has_pi']:
            return stage1
        
        # Stage 2 optional
        if use_ai and self.ai_client:
            stage2 = await self.stage2_detect(text)
            if stage2['has_pi']:
                return stage2
        
        return {'has_pi': False}

# Usage
pi_detector = PIDetector(ai_client=openai_client)

@app.route("/api/conversation", methods=["POST"])
async def conversation():
    message = request_json["messages"][-1]["content"]
    
    # Check for PI
    pi_check = await pi_detector.detect(
        message,
        use_ai=Config.PRODUCTION  # Only in prod
    )
    
    if pi_check['has_pi']:
        return jsonify({
            'error': 'personal_information_detected',
            'detected_types': [d['type'] for d in pi_check['detected']],
            'redacted_preview': pi_check.get('redacted_text', '')[:200],
            'message': 'Your question contains personal information. Please remove specific names, case numbers, or identifying details.'
        }), 400
    
    # Safe to process
    ...
```

---

## Pattern 3: Short-Circuit with Vector Similarity

### Implementation
```python
# app/backend/optimization/short_circuit.py

from azure.cosmos import CosmosClient
from langchain.embeddings import AzureOpenAIEmbeddings
from typing import Optional, Dict, List
import time

class ShortCircuitService:
    """Reuse previous answers for similar questions"""
    
    def __init__(self, cosmos_client: CosmosClient, embeddings: AzureOpenAIEmbeddings):
        self.cosmos = cosmos_client
        self.embeddings = embeddings
        self.cache_container = cosmos_client.get_database_client('eva').get_container_client('answer_cache')
    
    async def find_similar(
        self, 
        question: str, 
        threshold: float = 0.85,
        max_age_days: int = 90
    ) -> Optional[Dict]:
        """
        Search for previous similar answer
        
        Args:
            question: User's question
            threshold: Minimum similarity score (0-1)
            max_age_days: Maximum age of cached answer
        
        Returns:
            Cached answer if found, None otherwise
        """
        start_time = time.time()
        
        # Generate embedding
        embedding = await self.embeddings.aembed_query(question)
        
        # Cosmos DB vector search
        query = """
        SELECT TOP 5 
            c.id,
            c.question,
            c.answer,
            c.citation_url,
            c.created_at,
            VectorDistance(c.question_embedding, @embedding) AS similarity
        FROM c
        WHERE c.created_at > DateTimeAdd('day', @max_age, GetCurrentDateTime())
        ORDER BY VectorDistance(c.question_embedding, @embedding)
        """
        
        results = self.cache_container.query_items(
            query=query,
            parameters=[
                {"name": "@embedding", "value": embedding},
                {"name": "@max_age", "value": -max_age_days}
            ],
            enable_cross_partition_query=True
        )
        
        candidates = list(results)
        
        if not candidates:
            return None
        
        # Check top match
        top_match = candidates[0]
        if top_match['similarity'] >= threshold:
            # Validate citation still works
            if self._validate_citation(top_match['citation_url']):
                elapsed_ms = int((time.time() - start_time) * 1000)
                
                return {
                    'answer': top_match['answer'],
                    'citation_url': top_match['citation_url'],
                    'similarity_score': top_match['similarity'],
                    'original_question': top_match['question'],
                    'cached': True,
                    'latency_ms': elapsed_ms
                }
        
        return None
    
    def _validate_citation(self, url: str) -> bool:
        """Quick check if citation URL still valid"""
        try:
            response = requests.head(url, timeout=3)
            return response.status_code < 400
        except:
            return False
    
    async def cache_answer(
        self,
        question: str,
        answer: str,
        citation_url: str,
        metadata: Dict
    ):
        """Store answer for future reuse"""
        embedding = await self.embeddings.aembed_query(question)
        
        document = {
            'id': str(uuid.uuid4()),
            'question': question,
            'question_embedding': embedding,
            'answer': answer,
            'citation_url': citation_url,
            'metadata': metadata,
            'created_at': datetime.utcnow().isoformat(),
            'reuse_count': 0
        }
        
        self.cache_container.create_item(document)

# Usage in conversation handler
short_circuit = ShortCircuitService(cosmos_client, embeddings)

@app.route("/api/conversation", methods=["POST"])
async def conversation():
    question = request_json["messages"][-1]["content"]
    
    # Check cache first
    cached = await short_circuit.find_similar(question)
    
    if cached:
        logger.info(f"Short-circuit hit (similarity: {cached['similarity_score']:.2f})")
        
        return jsonify({
            'answer': cached['answer'],
            'citation': cached['citation_url'],
            'cached': True,
            'latency_ms': cached['latency_ms']
        })
    
    # Cache miss, generate new answer
    answer = await generate_answer(question)
    
    # Store for future
    await short_circuit.cache_answer(
        question=question,
        answer=answer['text'],
        citation_url=answer['citation'],
        metadata={'model': 'gpt-4', 'tokens': answer['tokens']}
    )
    
    return jsonify(answer)
```

---

## Pattern 4: Agentic Web Scraping Tool

### LangChain Tool Implementation
```python
# app/backend/tools/web_scraper.py

from langchain.tools import tool
import requests
from bs4 import BeautifulSoup
from markdownify import markdownify as md
from tiktoken import encoding_for_model
from typing import Optional

# Token budget for web content
MAX_TOKENS = 32000
encoder = encoding_for_model("gpt-4")

def clip_to_tokens(text: str, max_tokens: int = MAX_TOKENS) -> str:
    """Clip text to token budget"""
    tokens = encoder.encode(text)
    if len(tokens) <= max_tokens:
        return text
    return encoder.decode(tokens[:max_tokens])

@tool
def download_legal_document(url: str) -> str:
    """
    Download and parse legal documents (case law, legislation).
    
    Use this tool to:
    - Verify current version of legislation
    - Read specific case law
    - Get exact wording from official sources
    - Check time-sensitive legal content
    
    Supports:
    - CanLII (canlii.org)
    - Justice Laws (laws.justice.gc.ca)
    - Supreme Court (scc-csc.ca)
    - Federal Courts (fca-caf.gc.ca, fct-cf.gc.ca)
    
    Args:
        url: Full URL to legal document
    
    Returns:
        Markdown-formatted content of the document
    
    Raises:
        ValueError: If download fails or URL inaccessible
    """
    try:
        # Request with proper headers
        headers = {
            'User-Agent': 'EVA-Jurisprudence/1.2 (Canadian Government AI Assistant)'
        }
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Remove non-content elements
        for element in soup(['script', 'style', 'nav', 'header', 'footer']):
            element.decompose()
        
        # Find main content by site
        main_content = None
        
        if 'canlii.org' in url:
            # CanLII structure
            main_content = (
                soup.find('div', class_='documentcontent') or
                soup.find('article')
            )
        elif 'laws.justice.gc.ca' in url:
            # Justice Laws structure
            main_content = soup.find('main')
        elif 'scc-csc.ca' in url or 'fca-caf.gc.ca' in url:
            # Court decision structure
            main_content = (
                soup.find('div', id='core-content') or
                soup.find('main')
            )
        else:
            # Generic fallback
            main_content = soup.find('main') or soup.find('article') or soup.find('body')
        
        if not main_content:
            raise ValueError(f"Could not find main content in {url}")
        
        # Convert to markdown
        markdown_content = md(str(main_content), heading_style="ATX")
        
        # Extract title if available
        title = soup.find('h1')
        if title:
            markdown_content = f"# {title.get_text(strip=True)}\n\nSource: {url}\n\n{markdown_content}"
        
        # Clean up whitespace
        lines = [line.rstrip() for line in markdown_content.split('\n')]
        markdown_content = '\n'.join(line for line in lines if line or lines[lines.index(line)-1])
        
        # Clip to token budget
        return clip_to_tokens(markdown_content)
        
    except requests.exceptions.Timeout:
        raise ValueError(f"Request timed out: {url}")
    except requests.exceptions.HTTPError as e:
        raise ValueError(f"HTTP error {e.response.status_code}: {url}")
    except Exception as e:
        raise ValueError(f"Failed to download {url}: {str(e)}")

@tool  
def search_canlii(query: str, jurisdiction: str = "ca") -> str:
    """
    Search CanLII for relevant case law.
    
    Use when:
    - Initial search results insufficient
    - Need specific cases on a topic
    - Verifying legal principle or precedent
    
    Args:
        query: Search terms (e.g., "summary judgment test")
        jurisdiction: "ca" (federal) or provincial code ("on", "bc", etc.)
    
    Returns:
        JSON string with top 5 results: [{"title": "...", "url": "...", "snippet": "..."}]
    """
    # Implement CanLII API or scraping
    # (CanLII has an API: https://www.canlii.org/en/info/api.html)
    ...

# Create agent with tools
from langgraph.prebuilt import create_react_agent
from langchain_openai import AzureChatOpenAI

llm = AzureChatOpenAI(
    model="gpt-4",
    temperature=0
)

tools = [download_legal_document, search_canlii]

eva_agent = create_react_agent(
    model=llm,
    tools=tools,
    state_modifier=system_prompt
)

# Use agent
result = eva_agent.invoke({
    "messages": [
        {"role": "user", "content": "What was decided in R v Jordan about trial delays?"}
    ]
})

# Agent will autonomously:
# 1. Recognize it needs specific case
# 2. Call search_canlii("R v Jordan trial delays")
# 3. Get CanLII URL
# 4. Call download_legal_document(url)
# 5. Read full case
# 6. Generate answer with exact citations
```

---

## Pattern 5: System Prompt with Tool Instructions

### AI Answers Pattern
```javascript
// agents/prompts/agenticBase.js
const TOOL_INSTRUCTIONS = `
Step 3. MANDATORY downloadWebPage TOOL CHECKPOINT

Before crafting your answer, determine if downloadWebPage is required.
Check ALL conditions:

□ Answer needs specific details: contact, phone, codes, dates, amounts
□ Content is time-sensitive: news, budgets, updates, policy changes
□ URL unfamiliar or date AFTER training cutoff
□ Complex policy, regulations, requirements, laws, eligibility
□ Question matches "⚠️ TOOL-REQUIRED" trigger in scenarios

MANDATORY ACTION:
• If ANY checkbox TRUE → Call downloadWebPage NOW for 1-2 most relevant URLs
• If ALL FALSE → Proceed without download
`;
```

### EVA Adaptation
```python
# app/backend/prompts/eva_system_prompt.py

EVA_TOOL_INSTRUCTIONS = """
CRITICAL: AUTONOMOUS TOOL USAGE DECISION FRAMEWORK

Before generating your answer, evaluate if you should use tools:

DOWNLOAD LEGAL DOCUMENT TOOL - Use when:
□ Question asks about specific case law or legislation
□ URL in context is from official legal source (CanLII, Justice Laws, SCC, FCA)
□ Need exact wording of legal provision or case holding
□ Document date is AFTER April 2023 (your training cutoff)
□ Question requires verification of current version
□ Time-sensitive legal content (recent amendments, new precedents)

SEARCH CANLII TOOL - Use when:
□ User asks "what did court decide in [case name]"
□ Need to find relevant precedents for legal principle
□ Initial context insufficient for accurate answer
□ User references case you're uncertain about

URL VALIDATION - ALWAYS use before citing:
□ Every URL you include in citation MUST be validated
□ If invalid, use jurisdiction homepage as fallback

EXAMPLE REASONING:
User: "What was decided in R v Jordan about trial delays?"

Your thought process:
- This asks about specific Supreme Court case
- R v Jordan is after my training cutoff
- Need exact holdings and reasoning
- ✓ SHOULD use search_canlii to find case
- ✓ THEN use download_legal_document to read full decision
- ✓ FINALLY validate citation URL before returning

ACTION:
1. search_canlii("R v Jordan trial delays", "ca")
2. download_legal_document(result_url)
3. Generate answer based on full case text
4. validate_citation_url(citation)

IMPORTANT:
- Tools are MANDATORY for accuracy, not optional
- Use multiple tools in sequence if needed
- Always explain your tool usage in hidden reasoning
"""

# Full system prompt
EVA_SYSTEM_PROMPT = f"""
You are EVA (Electronic Virtual Assistant), an AI assistant specializing in 
Canadian federal jurisprudence. You help users understand legal procedures,
find relevant case law, and navigate the federal court system.

{EVA_TOOL_INSTRUCTIONS}

ANSWER STRUCTURE:
1. Brief direct answer (2-3 sentences)
2. Key legal principles or holdings
3. Relevant citations with validated URLs
4. Next steps or additional resources

CONSTRAINTS:
- Never provide legal advice on specific cases
- Always cite official sources (CanLII, Justice Laws, court sites)
- Validate all citation URLs before returning
- If uncertain, search for verification

BEGIN PROCESSING USER QUESTION:
"""
```

---

## Pattern 6: Error Handling & Retries

### AI Answers Pattern
```javascript
// agents/graphs/workflows/GraphWorkflowHelper.js
class GraphWorkflowHelper {
  async withRetry(fn, maxRetries = 3, backoff = 1000) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await fn();
      } catch (error) {
        if (attempt === maxRetries) {
          throw error;
        }
        
        // Exponential backoff
        const delay = backoff * Math.pow(2, attempt - 1);
        await new Promise(resolve => setTimeout(resolve, delay));
        
        logger.warn(`Retry ${attempt}/${maxRetries} after ${delay}ms`, error);
      }
    }
  }
}
```

### EVA Python Implementation
```python
# app/backend/utils/retry.py

import time
import logging
from typing import Callable, TypeVar, Any
from functools import wraps

logger = logging.getLogger(__name__)

T = TypeVar('T')

def with_retry(
    max_attempts: int = 3,
    backoff_base: float = 1.0,
    exceptions: tuple = (Exception,)
):
    """
    Retry decorator with exponential backoff
    
    Args:
        max_attempts: Maximum retry attempts
        backoff_base: Base delay in seconds
        exceptions: Tuple of exceptions to catch
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        async def async_wrapper(*args, **kwargs) -> T:
            for attempt in range(1, max_attempts + 1):
                try:
                    return await func(*args, **kwargs)
                except exceptions as e:
                    if attempt == max_attempts:
                        logger.error(f"{func.__name__} failed after {max_attempts} attempts: {e}")
                        raise
                    
                    delay = backoff_base * (2 ** (attempt - 1))
                    logger.warning(f"{func.__name__} attempt {attempt}/{max_attempts} failed, retrying in {delay}s: {e}")
                    time.sleep(delay)
            
            raise RuntimeError(f"Should not reach here")
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs) -> T:
            for attempt in range(1, max_attempts + 1):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    if attempt == max_attempts:
                        logger.error(f"{func.__name__} failed after {max_attempts} attempts: {e}")
                        raise
                    
                    delay = backoff_base * (2 ** (attempt - 1))
                    logger.warning(f"{func.__name__} attempt {attempt}/{max_attempts} failed, retrying in {delay}s: {e}")
                    time.sleep(delay)
            
            raise RuntimeError(f"Should not reach here")
        
        # Return appropriate wrapper based on function type
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator

# Usage
@with_retry(max_attempts=3, backoff_base=1.0)
async def download_with_retry(url: str) -> str:
    """Download with automatic retry on failure"""
    return await download_legal_document(url)

@with_retry(max_attempts=2, backoff_base=0.5, exceptions=(requests.Timeout,))
def validate_url_with_retry(url: str) -> bool:
    """Validate URL with retry on timeout"""
    response = requests.head(url, timeout=5)
    return response.status_code < 400
```

---

## Complete Integration Example

### Putting It All Together
```python
# app/backend/api/conversation_v2.py (Enhanced version)

from quart import Blueprint, request, jsonify
from langchain_openai import AzureChatOpenAI
from langgraph.prebuilt import create_react_agent

from ..tools.web_scraper import download_legal_document, search_canlii
from ..utils.citation_validator import CitationValidator
from ..security.pi_detector import PIDetector
from ..optimization.short_circuit import ShortCircuitService
from ..utils.retry import with_retry

bp = Blueprint('conversation_v2', __name__)

# Initialize services
pi_detector = PIDetector(ai_client)
validator = CitationValidator()
short_circuit = ShortCircuitService(cosmos_client, embeddings)

# Create agentic LLM
llm = AzureChatOpenAI(model="gpt-4", temperature=0)
tools = [download_legal_document, search_canlii]
agent = create_react_agent(llm, tools, state_modifier=EVA_SYSTEM_PROMPT)

@bp.route("/api/conversation/v2", methods=["POST"])
async def conversation_v2():
    """Enhanced conversation endpoint with full AI Answers patterns"""
    
    request_json = await request.get_json()
    message = request_json["messages"][-1]["content"]
    
    # STEP 1: PI Detection (Two-stage)
    pi_check = await pi_detector.detect(message, use_ai=Config.PRODUCTION)
    if pi_check['has_pi']:
        return jsonify({
            'error': 'personal_information_detected',
            'detected_types': [d['type'] for d in pi_check['detected']],
            'guidance': 'Please rephrase without personal details.'
        }), 400
    
    # STEP 2: Short-Circuit Check
    cached = await short_circuit.find_similar(message)
    if cached:
        return jsonify({
            'answer': cached['answer'],
            'citation': cached['citation_url'],
            'cached': True,
            'latency_ms': cached['latency_ms']
        })
    
    # STEP 3: Agent Processing (with tools)
    try:
        result = await agent.ainvoke({
            "messages": [{"role": "user", "content": message}]
        })
        
        answer_text = result['messages'][-1].content
        citation_url = extract_citation(answer_text)
        
    except Exception as e:
        logger.error(f"Agent processing failed: {e}")
        return jsonify({'error': 'processing_failed'}), 500
    
    # STEP 4: Citation Validation
    validation = validator.validate(citation_url)
    if not validation['valid']:
        logger.warning(f"Invalid citation: {citation_url}")
        fallback_url = validator.get_fallback(citation_url, message)
        answer_text = answer_text.replace(citation_url, fallback_url)
        citation_url = fallback_url
    
    # STEP 5: Cache for Future
    await short_circuit.cache_answer(
        question=message,
        answer=answer_text,
        citation_url=citation_url,
        metadata={'model': 'gpt-4', 'tools_used': result.get('tools_used', [])}
    )
    
    # STEP 6: Return Response
    return jsonify({
        'answer': answer_text,
        'citation': citation_url,
        'cached': False,
        'tools_used': result.get('tools_used', []),
        'confidence': result.get('confidence', 8)
    })
```

---

## Testing Patterns

### Unit Tests
```python
# tests/test_citation_validator.py

import pytest
from app.backend.utils.citation_validator import CitationValidator

@pytest.fixture
def validator():
    return CitationValidator(timeout=5)

def test_validate_valid_url(validator):
    result = validator.validate('https://laws.justice.gc.ca/eng/acts/F-7/')
    assert result['valid'] == True
    assert result['status'] == 200

def test_validate_invalid_url(validator):
    result = validator.validate('https://laws.justice.gc.ca/invalid-page-12345')
    assert result['valid'] == False

def test_get_fallback_fca(validator):
    fallback = validator.get_fallback(
        'https://decisions.fca-caf.gc.ca/broken/link',
        'appeal procedure'
    )
    assert 'fca-caf.gc.ca' in fallback

def test_get_fallback_canlii(validator):
    fallback = validator.get_fallback(
        'https://www.canlii.org/en/ca/fca/doc/broken',
        'contract law'
    )
    assert 'canlii.org' in fallback
    assert 'contract%20law' in fallback  # URL encoded
```

### Integration Tests
```python
# tests/integration/test_conversation_v2.py

import pytest
from app.backend.api.conversation_v2 import bp

@pytest.mark.asyncio
async def test_conversation_blocks_pi(client):
    response = await client.post('/api/conversation/v2', json={
        'messages': [
            {'role': 'user', 'content': 'My case number is 2024-12345, what should I do?'}
        ]
    })
    
    assert response.status_code == 400
    data = await response.get_json()
    assert 'personal_information_detected' in data['error']
    assert 'case_file' in [d['type'] for d in data['detected_types']]

@pytest.mark.asyncio
async def test_conversation_uses_cache(client, mock_short_circuit):
    # First request (cache miss)
    response1 = await client.post('/api/conversation/v2', json={
        'messages': [{'role': 'user', 'content': 'How do I appeal?'}]
    })
    data1 = await response1.get_json()
    assert data1['cached'] == False
    
    # Second request (cache hit)
    response2 = await client.post('/api/conversation/v2', json={
        'messages': [{'role': 'user', 'content': 'How can I file an appeal?'}]
    })
    data2 = await response2.get_json()
    assert data2['cached'] == True
    assert data2['latency_ms'] < data1.get('latency_ms', 10000)

@pytest.mark.asyncio
async def test_conversation_validates_citation(client):
    response = await client.post('/api/conversation/v2', json={
        'messages': [{'role': 'user', 'content': 'What are Federal Court rules?'}]
    })
    
    data = await response.get_json()
    citation = data['citation']
    
    # Citation should be valid
    validator = CitationValidator()
    validation = validator.validate(citation)
    assert validation['valid'] == True
```

---

## Monitoring & Observability

### Logging Pattern
```python
# app/backend/utils/structured_logger.py

import logging
import json
from datetime import datetime

class StructuredLogger:
    """Structured logging for EVA"""
    
    def __init__(self, name: str):
        self.logger = logging.getLogger(name)
    
    def log_event(self, level: str, event_type: str, **kwargs):
        """Log structured event"""
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'event_type': event_type,
            **kwargs
        }
        
        getattr(self.logger, level)(json.dumps(log_entry))
    
    def log_tool_call(self, tool_name: str, input_data: dict, output_data: dict, duration_ms: int):
        """Log tool usage"""
        self.log_event(
            'info',
            'tool_call',
            tool_name=tool_name,
            input=input_data,
            output_summary=str(output_data)[:200],
            duration_ms=duration_ms
        )
    
    def log_short_circuit(self, hit: bool, similarity_score: float):
        """Log cache hit/miss"""
        self.log_event(
            'info',
            'short_circuit',
            hit=hit,
            similarity_score=similarity_score
        )

# Usage
logger = StructuredLogger(__name__)

logger.log_tool_call(
    tool_name='download_legal_document',
    input_data={'url': 'https://...'},
    output_data={'length': 5000, 'tokens': 1500},
    duration_ms=1234
)
```

---

## Configuration Management

### Environment-Based Config
```python
# app/backend/config.py

import os
from dataclasses import dataclass

@dataclass
class EVAConfig:
    """EVA configuration with environment overrides"""
    
    # Feature flags
    ENABLE_PI_DETECTION_STAGE1: bool = True
    ENABLE_PI_DETECTION_STAGE2: bool = os.getenv('ENV') == 'production'
    ENABLE_SHORT_CIRCUIT: bool = True
    ENABLE_CITATION_VALIDATION: bool = True
    ENABLE_AGENTIC_TOOLS: bool = True
    
    # Performance tuning
    SHORT_CIRCUIT_THRESHOLD: float = float(os.getenv('SHORT_CIRCUIT_THRESHOLD', '0.85'))
    SHORT_CIRCUIT_MAX_AGE_DAYS: int = int(os.getenv('SHORT_CIRCUIT_MAX_AGE_DAYS', '90'))
    URL_VALIDATION_TIMEOUT: int = int(os.getenv('URL_VALIDATION_TIMEOUT', '5'))
    
    # Model selection
    ANSWER_MODEL: str = os.getenv('ANSWER_MODEL', 'gpt-4')
    PI_DETECTION_MODEL: str = os.getenv('PI_DETECTION_MODEL', 'gpt-4o-mini')
    EMBEDDING_MODEL: str = os.getenv('EMBEDDING_MODEL', 'text-embedding-3-small')
    
    # Tool configuration
    MAX_TOOL_RETRIES: int = 3
    TOOL_TIMEOUT: int = 15
    
    @classmethod
    def for_environment(cls, env: str):
        """Get config for specific environment"""
        configs = {
            'development': cls(
                ENABLE_PI_DETECTION_STAGE2=False,  # Save costs in dev
                ENABLE_SHORT_CIRCUIT=True,
                SHORT_CIRCUIT_THRESHOLD=0.90  # Higher threshold in dev
            ),
            'staging': cls(
                ENABLE_PI_DETECTION_STAGE2=True,
                ENABLE_SHORT_CIRCUIT=True,
                SHORT_CIRCUIT_THRESHOLD=0.85
            ),
            'production': cls(
                ENABLE_PI_DETECTION_STAGE2=True,
                ENABLE_SHORT_CIRCUIT=True,
                ENABLE_CITATION_VALIDATION=True,
                SHORT_CIRCUIT_THRESHOLD=0.85
            )
        }
        return configs.get(env, cls())

# Usage
config = EVAConfig.for_environment(os.getenv('ENV', 'development'))
```

---

**For complete implementation plan, see:** [08-INTEGRATION-PLAN.md](08-INTEGRATION-PLAN.md)

**For architectural comparison, see:** [07-EVA-COMPARISON.md](07-EVA-COMPARISON.md)

**For overview, see:** [00-README.md](00-README.md)
