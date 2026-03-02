# EVA Enhancement - Integration Plan

**Based on:** AI Answers architecture analysis  
**Target:** EVA Jurisprudence v1.2+  
**Approach:** Phased implementation with measurable outcomes

---

## Executive Summary

This plan outlines a **3-phase approach** to enhance EVA with proven patterns from AI Answers:

**Phase 1 (Sprint 1-2):** Quick wins - URL validation, PI detection, basic tools  
**Phase 2 (Sprint 3-5):** Performance - Short-circuit, context reuse, evaluation  
**Phase 3 (Sprint 6-8):** Advanced - LangGraph migration, advanced tools, continuous improvement

**Expected outcomes:**
- 🎯 80% reduction in broken citations (Phase 1)
- 🎯 2x faster responses for common questions (Phase 2)
- 🎯 90%+ accuracy on legal queries (Phase 3)
- 🎯 70% cost reduction through optimization (Phase 2-3)

---

## Phase 1: Foundation & Quick Wins

**Duration:** 2 sprints (3-4 weeks)  
**Risk:** Low  
**ROI:** High

### Objectives

1. Eliminate broken citations
2. Implement privacy protection
3. Add basic agentic tools
4. Establish evaluation baseline

### Epic 1.1: URL Validation Service

**Story Points:** 3  
**Priority:** P0 (Critical)

**User Story:**
```
As a user,
I want citations to be valid and accessible,
So that I can trust and use the provided resources.
```

**Acceptance Criteria:**
- [ ] All citation URLs validated before returning to user
- [ ] Broken URLs automatically replaced with fallback
- [ ] Validation results logged for monitoring
- [ ] < 500ms validation time per URL

**Implementation:**

```python
# File: app/backend/utils/url_validator.py

import requests
from typing import Dict, Optional
import logging

logger = logging.getLogger(__name__)

class URLValidator:
    """Validate citation URLs before returning to users"""
    
    def __init__(self, timeout: int = 5):
        self.timeout = timeout
        self.session = requests.Session()
    
    def validate(self, url: str) -> Dict:
        """
        Validate URL accessibility
        
        Returns:
            {
                'valid': bool,
                'status': int,
                'final_url': str,  # After redirects
                'latency_ms': int
            }
        """
        try:
            start_time = time.time()
            
            # Try HEAD first (fast, no body)
            response = self.session.head(
                url,
                timeout=self.timeout,
                allow_redirects=True
            )
            
            latency_ms = int((time.time() - start_time) * 1000)
            
            is_valid = 200 <= response.status_code < 400
            
            return {
                'valid': is_valid,
                'status': response.status_code,
                'final_url': response.url,
                'latency_ms': latency_ms
            }
            
        except requests.exceptions.Timeout:
            logger.warning(f"URL validation timeout: {url}")
            return {'valid': False, 'status': 408, 'error': 'timeout'}
            
        except requests.exceptions.RequestException as e:
            logger.error(f"URL validation failed: {url} - {e}")
            return {'valid': False, 'status': 0, 'error': str(e)}
    
    def get_fallback_url(self, original_url: str, query: str) -> str:
        """
        Generate fallback URL if original is invalid
        
        Priority:
        1. Court/jurisdiction home page
        2. CanLII search
        3. Justice Laws search
        """
        # Extract jurisdiction from URL
        if 'fca-caf.gc.ca' in original_url:
            return 'https://www.fca-caf.gc.ca/en'
        elif 'scc-csc.ca' in original_url:
            return 'https://www.scc-csc.ca/home-accueil/index-eng.aspx'
        elif 'canlii.org' in original_url:
            # CanLII search fallback
            return f'https://www.canlii.org/en/#search/text={query}'
        else:
            # Justice Laws fallback
            return 'https://laws.justice.gc.ca/eng/'

# Integration point
url_validator = URLValidator()
```

**Usage in existing code:**
```python
# File: app/backend/approaches/chatreadretrieveread.py

async def run(self, ...):
    # ... existing answer generation ...
    
    # NEW: Validate citation before returning
    citation_url = self.extract_citation_url(answer)
    
    validation = url_validator.validate(citation_url)
    
    if not validation['valid']:
        logger.warning(f"Invalid citation: {citation_url} (status: {validation['status']})")
        
        # Use fallback instead
        fallback_url = url_validator.get_fallback_url(citation_url, query)
        answer = answer.replace(citation_url, fallback_url)
        
        # Log for monitoring
        await self.log_invalid_citation(citation_url, fallback_url, validation)
    
    return answer
```

**Testing:**
```python
# tests/test_url_validator.py

def test_validate_valid_url():
    validator = URLValidator()
    result = validator.validate('https://laws.justice.gc.ca/eng/acts/F-7/')
    assert result['valid'] == True
    assert result['status'] == 200

def test_validate_invalid_url():
    validator = URLValidator()
    result = validator.validate('https://laws.justice.gc.ca/invalid-page')
    assert result['valid'] == False
    assert result['status'] == 404

def test_validate_timeout():
    validator = URLValidator(timeout=0.001)  # Very short
    result = validator.validate('https://slow-site.com/page')
    assert result['valid'] == False
    assert 'timeout' in result.get('error', '')
```

**Rollout:**
- Week 1: Implementation + unit tests
- Week 2: Integration testing
- Week 3: Canary deployment (10% traffic)
- Week 4: Full rollout + monitoring

**Success Metrics:**
- Baseline broken citation rate: ~15-20%
- Target broken citation rate: < 2%
- **Expected:** 80-90% reduction in broken citations

---

### Epic 1.2: Two-Stage PI Detection

**Story Points:** 5  
**Priority:** P0 (Critical for Secrecy Mode)

**User Story:**
```
As a user with sensitive information,
I want my personal details blocked before processing,
So that my privacy is protected.
```

**Acceptance Criteria:**
- [ ] Stage 1 pattern detection blocks common PI instantly
- [ ] Stage 2 AI detection catches edge cases (production only)
- [ ] User sees what was detected (redacted with XXX)
- [ ] Blocked questions never logged or processed
- [ ] < 100ms for Stage 1, < 500ms for Stage 2

**Implementation:**

```python
# File: app/backend/security/pi_detection.py

import re
from typing import Dict, List, Optional
from openai import AzureOpenAI

class PIDetectionService:
    """Two-stage personal information detection for EVA"""
    
    # Stage 1: Fast pattern-based detection
    PATTERNS = {
        'phone': r'\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b',
        'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        'sin': r'\b\d{9}\b',
        'postal_code': r'\b[A-Z]\d[A-Z]\s?\d[A-Z]\d\b',
        'case_file': r'\b(file|case|docket)\s*(no|number)?\.?\s*\d{4,}[-/]\d+\b',
        'address': r'\b\d+\s+[A-Za-z\s]+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr)\b',
    }
    
    def __init__(self, ai_client: Optional[AzureOpenAI] = None):
        self.ai_client = ai_client
    
    def detect_stage1(self, text: str) -> Dict:
        """
        Fast pattern-based detection (no AI, < 100ms)
        
        Returns:
            {
                'has_pi': bool,
                'detected_types': List[str],
                'redacted_text': str,
                'confidence': 'high' | 'pattern'
            }
        """
        detected_types = []
        redacted_text = text
        
        for pi_type, pattern in self.PATTERNS.items():
            if re.search(pattern, text, re.IGNORECASE):
                detected_types.append(pi_type)
                # Redact with XXX to show user what was detected
                redacted_text = re.sub(
                    pattern, 
                    'XXX', 
                    redacted_text, 
                    flags=re.IGNORECASE
                )
        
        return {
            'has_pi': len(detected_types) > 0,
            'detected_types': detected_types,
            'redacted_text': redacted_text,
            'confidence': 'high',
            'stage': 1
        }
    
    async def detect_stage2(self, text: str) -> Dict:
        """
        AI-powered detection for edge cases (GPT-4 Mini, < 500ms)
        
        Catches:
        - Person names
        - Personal identifiers
        - Sensitive context
        """
        if not self.ai_client:
            return {'has_pi': False, 'stage': 2, 'skipped': True}
        
        prompt = f"""You are a privacy protection expert. Analyze this text for personal information:

Text: "{text}"

Detect:
- Person names (first + last)
- Personal identifiers (health card, driver's license, etc.)
- Addresses or location details
- Case-specific identifying information

Return JSON:
{{
  "has_pi": true/false,
  "detected_types": ["person_name", "identifier", ...],
  "reasoning": "brief explanation"
}}

Be conservative - if unsure, flag as potential PI.
"""
        
        response = await self.ai_client.chat.completions.create(
            model="gpt-4-mini",  # Fast and cheap
            messages=[
                {"role": "system", "content": "You are a privacy protection expert. Output only valid JSON."},
                {"role": "user", "content": prompt}
            ],
            temperature=0,
            max_tokens=200
        )
        
        result = json.loads(response.choices[0].message.content)
        
        return {
            'has_pi': result['has_pi'],
            'detected_types': result.get('detected_types', []),
            'reasoning': result.get('reasoning', ''),
            'confidence': 'ai',
            'stage': 2
        }
    
    async def detect(self, text: str, use_ai: bool = False) -> Dict:
        """
        Full two-stage detection
        
        Args:
            text: User input to check
            use_ai: Whether to use Stage 2 (AI detection)
        
        Returns:
            Detection results with blocking recommendation
        """
        # Stage 1: Always run (fast, no cost)
        stage1 = self.detect_stage1(text)
        
        if stage1['has_pi']:
            return stage1
        
        # Stage 2: Optional (slower, small cost)
        if use_ai:
            stage2 = await self.detect_stage2(text)
            if stage2['has_pi']:
                return stage2
        
        return {'has_pi': False, 'stage': 1 if not use_ai else 2}

# Initialize service
pi_detection = PIDetectionService(ai_client=openai_client)
```

**Usage in request handler:**
```python
# File: app/backend/app.py

@app.route("/api/conversation", methods=["POST"])
async def conversation():
    request_json = await request.get_json()
    user_message = request_json["messages"][-1]["content"]
    
    # NEW: Check for PI before processing
    pi_check = await pi_detection.detect(
        user_message,
        use_ai=Config.ENABLE_AI_PI_DETECTION  # Stage 2 off for dev, on for prod
    )
    
    if pi_check['has_pi']:
        logger.warning(f"PI detected: {pi_check['detected_types']}")
        
        return jsonify({
            'error': 'personal_information_detected',
            'message': 'Your question appears to contain personal information.',
            'detected_types': pi_check['detected_types'],
            'redacted_preview': pi_check.get('redacted_text', '')[:100],
            'guidance': 'Please rephrase your question without specific names, case numbers, or personal details.'
        }), 400
    
    # Safe to proceed with conversation
    # ... existing logic ...
```

**Configuration:**
```python
# File: app/backend/config.py

class Config:
    # Stage 1: Always enabled (no cost, fast)
    ENABLE_STAGE1_PI_DETECTION = True
    
    # Stage 2: Enable in production only (has cost)
    ENABLE_AI_PI_DETECTION = os.getenv('ENV') == 'production'
```

**Testing:**
```python
# tests/test_pi_detection.py

def test_stage1_detects_phone():
    service = PIDetectionService()
    result = service.detect_stage1("Call me at 555-123-4567")
    assert result['has_pi'] == True
    assert 'phone' in result['detected_types']
    assert 'XXX' in result['redacted_text']

def test_stage1_detects_email():
    service = PIDetectionService()
    result = service.detect_stage1("Email john.doe@example.com")
    assert result['has_pi'] == True
    assert 'email' in result['detected_types']

def test_stage1_detects_case_number():
    service = PIDetectionService()
    result = service.detect_stage1("My case number is 2024-12345")
    assert result['has_pi'] == True
    assert 'case_file' in result['detected_types']

@pytest.mark.asyncio
async def test_stage2_detects_person_name():
    service = PIDetectionService(mock_ai_client)
    result = await service.detect_stage2("John Smith filed an appeal")
    assert result['has_pi'] == True
    assert 'person_name' in result['detected_types']
```

**Rollout:**
- Week 1: Stage 1 implementation
- Week 2: Stage 1 testing + deployment
- Week 3: Stage 2 implementation (production only)
- Week 4: Full testing + monitoring

**Success Metrics:**
- Stage 1 detection rate: > 90% of obvious PI
- Stage 2 additional catch rate: 5-10%
- False positive rate: < 2%
- Performance: Stage 1 < 100ms, Stage 2 < 500ms

---

### Epic 1.3: Basic Agentic Tools

**Story Points:** 8  
**Priority:** P1 (High)

**User Story:**
```
As EVA,
I want to download current legal content when needed,
So that I provide accurate and up-to-date answers.
```

**Implementation:**

```python
# File: app/backend/tools/legal_tools.py

from langchain.tools import tool
import requests
from bs4 import BeautifulSoup
import markdownify

@tool
def download_case_law(url: str) -> str:
    """
    Download and parse current case law or legislation.
    
    Use this tool when:
    - URL is from CanLII, SCC, FCA, or Justice Laws
    - Question asks about specific case or legislation
    - Need to verify current version
    - URL date is recent (after training cutoff)
    
    Args:
        url: Full URL to download
    
    Returns:
        Markdown-formatted content of the legal document
    """
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Extract main content
        # (CanLII uses <div class="documentcontent">)
        main_content = (
            soup.find('div', class_='documentcontent') or
            soup.find('main') or
            soup.find('article') or
            soup.find('body')
        )
        
        # Convert to markdown
        markdown_content = markdownify.markdownify(
            str(main_content),
            heading_style="ATX"
        )
        
        return markdown_content
        
    except Exception as e:
        raise ValueError(f"Failed to download {url}: {str(e)}")

@tool
def search_canlii(query: str, jurisdiction: str = "ca") -> list:
    """
    Search CanLII for relevant case law.
    
    Use when initial search results insufficient or need specific cases.
    
    Args:
        query: Search terms
        jurisdiction: 'ca' (federal) or provincial code
    
    Returns:
        List of case citations with URLs
    """
    # Implement CanLII API search
    # ...

# Create agent with tools
from langgraph.prebuilt import create_react_agent
from langchain_openai import AzureChatOpenAI

tools = [download_case_law, search_canlii]

agent = create_react_agent(
    model=AzureChatOpenAI(...),
    tools=tools,
    state_modifier=system_prompt
)
```

**See:** [09-CODE-PATTERNS.md](09-CODE-PATTERNS.md) for complete implementation

---

### Epic 1.4: Evaluation Baseline

**Story Points:** 5  
**Priority:** P1

**Deliverables:**
- [ ] Manual evaluation workflow for team
- [ ] 100-question test set with expert answers
- [ ] Baseline accuracy measurement
- [ ] Documentation for evaluators

**Success Metrics:**
- Baseline accuracy: 75-80%
- Target accuracy (Phase 3): 90%+

---

## Phase 2: Performance & Optimization

**Duration:** 3 sprints (5-6 weeks)  
**Dependencies:** Phase 1 complete  
**Risk:** Medium  
**ROI:** Very High

### Objectives

1. Implement short-circuit optimization
2. Add context reuse logic
3. Enhance evaluation with AI
4. Deploy court-specific scenarios

### Epic 2.1: Short-Circuit Optimization

**Story Points:** 8  
**Priority:** P0

**Expected Impact:**
- 60-80% of questions answered from cache
- 2-3x faster response times
- 70% cost reduction
- Consistent answers to similar questions

**Implementation:** See [09-CODE-PATTERNS.md](09-CODE-PATTERNS.md)

---

### Epic 2.2: Court-Specific Scenarios

**Story Points:** 13  
**Priority:** P1

**Structure:**
```
app/backend/prompts/court_scenarios/
├── federal_courts/
│   ├── fca_civil_appeals.md
│   ├── fca_judicial_review.md
│   └── fc_immigration.md
├── supreme_court/
│   ├── scc_civil.md
│   ├── scc_criminal.md
│   └── scc_leave_applications.md
└── provincial/
    ├── on_court_of_appeal.md
    └── ... (other provinces)
```

**Example Scenario:**
```markdown
# Federal Court of Appeal - Civil Appeals

## Priority Resources (download required)
- Federal Courts Rules: https://laws.justice.gc.ca/eng/regulations/SOR-98-106/ (Updated: 2024)
- Practice Direction: https://www.fca-caf.gc.ca/practice (⚠️ TOOL-REQUIRED)

## Common Questions

### Appeal Deadlines
Q: "How long do I have to appeal?"
- MUST specify: type of order (interlocutory vs final)
- Default: 30 days from date decision perfected
- Exception: judicial review (Federal Court) = 30 days from communication
- TOOL: Download current Rules for exact wording

### Filing Requirements
Q: "What documents do I need to file?"
- Notice of Appeal (Form 343 or 343.1)
- Memorandum of Fact and Law
- Record (within 60 days)
- MUST mention: extensions available on motion

### Jurisdiction Clarification
- FCA hearing appeals FROM Federal Court
- NOT first instance (except rare cases)
- If question about starting proceeding → clarify FCA vs FC

## Mandatory Actions
- [ ] Always verify limitations period from current Rules
- [ ] Include FCA Registry contact: 613-992-4238
- [ ] Mention self-represented litigant office if no lawyer
- [ ] Warn about strict deadlines (few extensions)

## Restrictions
- DON'T give legal advice on merits
- DON'T confirm whether appeal likely to succeed
- DON'T interpret specific facts (refer to lawyer)
```

---

## Phase 3: Advanced Features

**Duration:** 3-4 sprints (6-8 weeks)  
**Dependencies:** Phase 1-2 complete  
**Risk:** High  
**ROI:** High (long-term)

### Objectives

1. Migrate to LangGraph architecture
2. Implement advanced tools (court form locator, precedent search)
3. Deploy continuous evaluation
4. Real-time status streaming

### Epic 3.1: LangGraph Migration

**Story Points:** 21  
**Priority:** P1

**Approach:** Incremental migration, parallel systems

**Stages:**
1. Create graph structure (parallel to existing)
2. Migrate one endpoint (e.g., `/api/conversation/v2`)
3. A/B test both versions
4. Gradually shift traffic
5. Deprecate old endpoint

---

## Implementation Timeline

```
Month 1-2: Phase 1 (Foundation)
├─ Week 1-2: URL Validation
├─ Week 3-4: PI Detection Stage 1
├─ Week 5-6: Basic Tools
└─ Week 7-8: Evaluation Baseline

Month 3-4: Phase 2 (Performance)
├─ Week 9-11: Short-Circuit
├─ Week 12-14: Court Scenarios
└─ Week 15-16: Context Reuse + AI Evaluation

Month 5-6: Phase 3 (Advanced)
├─ Week 17-20: LangGraph Migration
├─ Week 21-23: Advanced Tools
└─ Week 24: SSE Streaming + Polish
```

---

## Risk Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| LangGraph learning curve | High | Medium | Parallel development, training |
| Performance degradation | Medium | High | Load testing, canary deployment |
| Tool reliability | Medium | High | Timeouts, fallbacks, monitoring |
| False PI positives | Low | Medium | Tunable thresholds, feedback loop |

### Operational Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Team capacity | Medium | Medium | Phased approach allows adjustment |
| User disruption | Low | High | Feature flags, gradual rollout |
| Cost increase | Low | Medium | Monitor costs, optimize prompts |

---

## Success Criteria

### Phase 1
- ✅ < 2% broken citations
- ✅ > 95% PI detection rate
- ✅ Basic tools functional and used
- ✅ Baseline evaluation complete

### Phase 2
- ✅ 60%+ short-circuit hit rate
- ✅ 2x faster average response
- ✅ 70% cost reduction
- ✅ Court scenarios deployed

### Phase 3
- ✅ LangGraph migration 100%
- ✅ 90%+ accuracy on evaluation
- ✅ Advanced tools in production
- ✅ Continuous evaluation running

---

## Resource Requirements

### Development Team
- 2 Senior Developers (Python/LangChain)
- 1 AI/ML Engineer (Prompt engineering)
- 1 QA Engineer (Testing + evaluation)
- 0.5 DevOps (Infrastructure)

### Legal Subject Matter Experts
- 2-3 hours/week for evaluation
- 1-2 days for scenario creation

### Infrastructure
- Azure OpenAI quota increase for tools
- Cosmos DB capacity for embeddings
- Monitoring and alerting setup

---

**Next Steps:**

1. Review and approve plan
2. Prioritize Phase 1 epics
3. Set up evaluation baseline
4. Begin URL validation implementation

**Questions? See:** [00-README.md](00-README.md) for overview or [07-EVA-COMPARISON.md](07-EVA-COMPARISON.md) for detailed comparison.
