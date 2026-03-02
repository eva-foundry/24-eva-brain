# Agentic Tools - Autonomous Decision Making

**Key Innovation:** AI agents autonomously decide when and how to use specialized tools during answer generation.

---

## Overview: What Makes This "Agentic"?

**Traditional RAG (EVA Current):**
```python
# Predetermined flow
def answer_question(question):
    chunks = vector_search(question)      # Always search
    answer = llm.generate(question, chunks)  # Always generate
    return answer                         # Always return
```

**Agentic RAG (AI Answers):**
```javascript
// AI decides what tools to use
async function answerQuestion(question, context) {
  // Agent has access to tools:
  // - downloadWebPage
  // - checkUrlStatus
  // - contextAgentTool
  
  // AI autonomously decides:
  // "This URL is from 2025, I should download it to verify"
  const pageContent = await downloadWebPage(url);
  
  // "This citation needs validation"
  const isValid = await checkUrlStatus(citationUrl);
  
  // "Initial context insufficient, need to re-derive"
  const newContext = await contextAgentTool(question);
  
  return generateAnswer(question, allData);
}
```

**Why this matters:**
- AI adapts to question complexity
- Verifies time-sensitive information
- Validates before returning
- Critical for legal/jurisprudence accuracy

---

## Tool #1: downloadWebPage

**File:** `C:\AICOE\ai-answers\agents\tools\downloadWebPage.js`

### Purpose

Download and parse current web pages to verify information accuracy.

### Implementation

```javascript
import { tool } from "@langchain/core/tools";
import axios from "axios";
import { JSDOM } from "jsdom";
import { Readability } from "@mozilla/readability";
import TurndownService from "turndown";
import { getEncoding } from "js-tiktoken";

const tokenizer = getEncoding("cl100k_base");
const DEFAULT_MAX_TOKENS = 32000;

function clipByTokens(text, maxTokens = DEFAULT_MAX_TOKENS) {
  const ids = tokenizer.encode(text);
  if (ids.length <= maxTokens) return text;
  return tokenizer.decode(ids.slice(0, maxTokens));
}

function htmlToLeanMarkdown(html, baseUrl) {
  // 1. Build DOM & run Readability to extract main content
  const dom = new JSDOM(html, { url: baseUrl });
  const reader = new Readability(dom.window.document);
  const article = reader.parse();

  // 2. Get main content HTML
  const contentHTML =
    (article && article.content) ||
    dom.window.document.querySelector("main")?.innerHTML ||
    dom.window.document.body?.innerHTML ||
    "";

  // 3. Convert to clean Markdown with Turndown
  const td = new TurndownService({
    headingStyle: "atx",
    bulletListMarker: "-",
    codeBlockStyle: "fenced",
  });

  let md = td.turndown(contentHTML);

  // 4. Add title if available
  if (article?.title) {
    md = `# ${article.title}\n\n` + md;
  }

  // 5. Normalize whitespace
  md = md
    .split("\n")
    .map((l) => l.trimEnd())
    .filter((l, i, arr) => !(l === "" && arr[i - 1] === ""))
    .join("\n");

  // 6. Clip to token budget (32K tokens ~ 24K words)
  return clipByTokens(md, DEFAULT_MAX_TOKENS);
}

async function downloadWebPage(url) {
  const config = {
    maxRedirects: 10,
    timeout: 5000,
    headers: { 
      "User-Agent": process.env.USER_AGENT || "ai-answers" 
    },
  };

  const res = await axios.get(url, config);
  
  return {
    markdown: htmlToLeanMarkdown(res.data, url),
    status: res.status,
    finalUrl: res.request.res.responseUrl  // After redirects
  };
}

const downloadWebPageTool = tool(
  async ({ url }) => {
    try {
      const { markdown } = await downloadWebPage(url);
      console.log("✓ Downloaded web page:", url);
      return markdown;
    } catch (error) {
      console.error("✗ Failed to download:", url, error.message);
      
      if (error.code === "ECONNREFUSED") {
        throw new Error(`Connection refused: ${url}`);
      }
      if (error.response?.status === 403) {
        throw new Error(`Access forbidden (403): ${url}`);
      }
      if (error.response?.status === 404) {
        throw new Error(`Page not found (404): ${url}`);
      }
      if (error.code === "ETIMEDOUT") {
        throw new Error(`Request timed out: ${url}`);
      }
      throw new Error(`Failed to download: ${url} - ${error.message}`);
    }
  },
  {
    name: "downloadWebPage",
    description: `Download a web page, extract main content with Mozilla Readability, 
and return clean Markdown. Use this tool to:
- Verify current information from government pages
- Get specific details (codes, dates, phone numbers, addresses)
- Check time-sensitive content (tax years, program updates, deadlines)
- Read pages modified after your training cutoff
- Validate unfamiliar URLs before citing them`,
    schema: {
      type: "object",
      properties: { 
        url: { 
          type: "string", 
          description: "Full URL to download and parse" 
        } 
      },
      required: ["url"],
    },
  }
);

export default downloadWebPageTool;
```

### When AI Uses This Tool

**Automatically triggered when:**

1. **Time-sensitive content**
   ```
   Q: "What are the tax brackets for 2025?"
   AI: Downloads current CRA page to get accurate 2025 brackets
   ```

2. **Unfamiliar URLs**
   ```
   Context: https://www.canada.ca/new-program-2025.html
   AI: "This URL is after my training cutoff, I should download it"
   ```

3. **Specific details needed**
   ```
   Q: "What's the phone number for Service Canada in Toronto?"
   AI: Downloads contact page to get current phone number
   ```

4. **Department scenario triggers**
   ```markdown
   ### EI Application
   **Priority URLs (⚠️ TOOL-REQUIRED):**
   - https://www.canada.ca/ei-apply.html (Updated: Nov 2024)
   
   AI sees ⚠️ TOOL-REQUIRED → automatically downloads URL
   ```

5. **Recent modifications**
   ```
   Search result shows: "Last updated: Jan 15, 2025"
   AI: "This is recent, I should verify current content"
   ```

### What AI Gets Back

**Input URL:** `https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/tax-return/completing-a-tax-return/deductions-credits-expenses.html`

**Output (Markdown):**
```markdown
# Deductions, credits, and expenses

You can claim deductions, credits, and expenses to reduce the amount of tax you have to pay.

## What's the difference?

**Deduction**: Reduces the amount of income you have to pay tax on
- Example: RRSP contribution of $5,000 reduces your taxable income by $5,000

**Credit**: Reduces the amount of tax you have to pay
- Non-refundable credit: Can reduce your tax to zero, but you won't get a refund
- Refundable credit: Can result in a refund if the credit is more than your tax owing

## Common deductions

- RRSP contributions
- Child care expenses
- Moving expenses
- Support payments

## Common credits

- Basic personal amount: $15,000 for 2024
- Canada employment amount: $1,368 for 2024
- Medical expenses
- Charitable donations

[View complete list of deductions](./deductions)
[View complete list of credits](./credits)
```

**Token count:** ~200 tokens (out of 32,000 budget)

### EVA Legal Application

**Scenario 1: Current Legislation**
```javascript
// EVA agent downloading current legislation
Q: "What's the current limitation period for Federal Court judicial review?"

AI Tool Call:
downloadWebPage({
  url: "https://laws.justice.gc.ca/eng/acts/F-7/section-18.1.html"
})

Returns:
# Federal Courts Act - Section 18.1
## Application for judicial review
(2) An application for judicial review... shall be made within
30 days after the time the decision or order was first communicated...
```

**Scenario 2: Recent Case Law**
```javascript
Q: "What did the Supreme Court decide in R v Jordan about trial delays?"

AI Tool Call:
downloadWebPage({
  url: "https://decisions.scc-csc.ca/scc-csc/scc-csc/en/item/16057/index.do"
})

Returns:
# R. v. Jordan, 2016 SCC 27
## Key Holdings:
- Presumptive ceiling: 18 months (provincial), 30 months (superior)
- Burden shifts to Crown if delay exceeds ceiling
- Transitional exceptional circumstances...
```

**Scenario 3: Court Rules Updates**
```javascript
Q: "What are the filing requirements for Federal Court appeals?"

AI sees in context: "Federal Courts Rules, SOR/98-106 (Amended: Dec 2024)"

AI Tool Call:
downloadWebPage({
  url: "https://laws.justice.gc.ca/eng/regulations/SOR-98-106/page-11.html"
})

Returns current rules with recent amendments
```

### Performance Considerations

**Token Budget:** 32,000 tokens (~24,000 words)
- Most pages: 500-2,000 tokens
- Complex pages: 3,000-5,000 tokens
- Maximum: 32,000 tokens (clipped automatically)

**Timing:**
- Page download: ~500-1,500ms
- HTML parsing: ~100-300ms
- Markdown conversion: ~50-100ms
- **Total: ~1-2 seconds per page**

**Cost Impact:**
- Input tokens increase by ~1,000-2,000 per download
- At $2.50/1M tokens: ~$0.0025-$0.005 per download
- Worth it for accuracy

**Caching:**
LangChain supports prompt caching:
```javascript
// Downloaded content cached for 5 minutes
// If another question needs same URL, uses cache
// Reduces cost by ~50% for repeated URLs
```

---

## Tool #2: checkUrlStatus

**File:** `C:\AICOE\ai-answers\agents\tools\checkURL.js`

### Purpose

Validate that a URL is accessible before using it as a citation.

### Implementation

```javascript
import { tool } from "@langchain/core/tools";
import axios from "axios";

async function checkUrlStatus(url) {
  try {
    // Try HEAD request first (fast, no body download)
    const response = await axios.head(url, {
      maxRedirects: 10,
      timeout: 10000,
      validateStatus: (status) => status >= 200 && status < 400
    });
    
    return {
      isValid: true,
      status: response.status,
      finalUrl: response.request.res.responseUrl
    };
  } catch (headError) {
    // HEAD failed, try GET as fallback
    try {
      const response = await axios.get(url, {
        maxRedirects: 10,
        timeout: 10000,
        validateStatus: (status) => status >= 200 && status < 400
      });
      
      return {
        isValid: true,
        status: response.status,
        finalUrl: response.request.res.responseUrl
      };
    } catch (getError) {
      return {
        isValid: false,
        status: getError.response?.status || 0,
        error: getError.message
      };
    }
  }
}

const checkUrlStatusTool = tool(
  async ({ url }) => {
    const result = await checkUrlStatus(url);
    
    if (result.isValid) {
      return `✓ Valid (${result.status})`;
    } else {
      return `✗ Invalid (${result.status || 'unreachable'}): ${result.error}`;
    }
  },
  {
    name: "checkUrlStatus",
    description: "Check if a URL is accessible and returns a valid response. Use before citing a URL.",
    schema: {
      type: "object",
      properties: {
        url: { type: "string", description: "URL to validate" }
      },
      required: ["url"],
    },
  }
);
```

### When AI Uses This Tool

```javascript
// During answer generation
AI: "I want to cite https://www.canada.ca/ei-benefits.html"

// Check if URL is valid
const status = await checkUrlStatus("https://www.canada.ca/ei-benefits.html");

if (status.isValid) {
  // Use as citation
  citationUrl = "https://www.canada.ca/ei-benefits.html";
} else {
  // Find alternative or use fallback
  citationUrl = fallbackDepartmentUrl;
}
```

### EVA Application

```javascript
// Validate case law citation
Q: "What's the test for summary judgment?"

AI wants to cite: "https://decisions.fca-caf.gc.ca/fca-caf/decisions/en/item/12345/"

Tool call: checkUrlStatus(url)
Result: ✗ Invalid (404)

AI: "URL not accessible, searching for alternative..."
Tool call: searchCitationAlternative("summary judgment test Canada")
Alt citation: "https://www.canlii.org/en/ca/fca/doc/2023/2023fca123/2023fca123.html"

Tool call: checkUrlStatus(altUrl)
Result: ✓ Valid (200)

Final citation: Uses alternative URL
```

---

## Tool #3: contextAgentTool

**File:** `C:\AICOE\ai-answers\agents\tools\contextAgentTool.js`

### Purpose

Re-derive context if initial context insufficient or question changes mid-conversation.

### Implementation

```javascript
import { tool } from "@langchain/core/tools";
import { contextService } from "../graphs/services/contextService.js";

const contextAgentTool = tool(
  async ({ question, reason }) => {
    console.log(`Re-deriving context. Reason: ${reason}`);
    
    // Run full context derivation
    const context = await contextService.deriveContext({
      question,
      searchProvider: 'canadaCa',
      lang: 'en'
    });
    
    return JSON.stringify({
      department: context.department,
      departmentUrl: context.departmentUrl,
      topic: context.topic,
      searchResults: context.searchResults.slice(0, 3),  // Top 3
      confidence: context.confidence
    }, null, 2);
  },
  {
    name: "contextAgentTool",
    description: `Re-derive context for a question if:
- Initial context seems incorrect for the question
- Question topic shifts during conversation
- Need more specific/relevant search results
- Department matching was ambiguous`,
    schema: {
      type: "object",
      properties: {
        question: { 
          type: "string", 
          description: "Question to derive context for" 
        },
        reason: {
          type: "string",
          description: "Why re-derivation is needed"
        }
      },
      required: ["question", "reason"],
    },
  }
);
```

### When AI Uses This Tool

**Scenario 1: Context Mismatch**
```javascript
Initial context: { department: "CRA", topic: "tax filing" }
Question: "How do I apply for EI?"

AI: "The context is about CRA/taxes but question is about EI benefits.
     I should re-derive context."

Tool call: contextAgentTool({
  question: "How do I apply for EI?",
  reason: "Initial context was tax-related, question is about EI benefits"
})

New context: { department: "ESDC", topic: "EI application" }
```

**Scenario 2: Topic Shift**
```javascript
Q1: "How do I renew my passport?"
Context: { department: "IRCC", topic: "passport renewal" }
Answer: [passport renewal info]

Q2: "What about getting a visa?"

AI: "Question shifted from passport to visa. Context still valid? 
     Both are IRCC but different topics. I should re-derive."

Tool call: contextAgentTool({
  question: "What about getting a visa?",
  reason: "Follow-up question shifted topic from passport to visa"
})

New context: { department: "IRCC", topic: "visa application" }
```

### EVA Application

```javascript
// Legal topic shift
Q1: "How do I appeal a Federal Court decision?"
Context: { jurisdiction: "FCA", topic: "civil appeals" }

Q2: "What if it's a criminal matter?"

AI: "Topic shifted from civil to criminal. Context needs update."

Tool call: contextAgentTool({
  question: "What if it's a criminal matter involving Federal Court?",
  reason: "Question shifted from civil to criminal jurisdiction"
})

New context: { 
  jurisdiction: "SCC",  // Supreme Court for criminal appeals
  topic: "criminal appeals",
  note: "Federal Court doesn't handle criminal - would be SCC"
}
```

---

## Tool Usage in Answer Generation

### How Tools Are Provided to Agent

```javascript
// agents/AgentFactory.js
import downloadWebPageTool from './tools/downloadWebPage.js';
import checkUrlStatusTool from './tools/checkURL.js';
import contextAgentTool from './tools/contextAgentTool.js';

export class AgentFactory {
  static async create({ type, model, chatId }) {
    const llm = new ChatOpenAI({
      modelName: model,
      temperature: 0,  // Deterministic
    });
    
    // Bind tools to LLM
    const llmWithTools = llm.bindTools([
      downloadWebPageTool,
      checkUrlStatusTool,
      contextAgentTool
    ]);
    
    // Create agent with tools
    const agent = createReactAgent({
      llm: llmWithTools,
      tools: [
        downloadWebPageTool,
        checkUrlStatusTool,
        contextAgentTool
      ],
      messageModifier: systemPrompt
    });
    
    return agent;
  }
}
```

### AI Decision Making Process

**System Prompt Guidance:**
```javascript
// agents/prompts/agenticBase.js
const TOOL_USAGE_INSTRUCTIONS = `
Step 3. MANDATORY downloadWebPage TOOL CHECKPOINT

Before crafting your answer, determine if downloadWebPage is required.
Check ALL conditions for URLs from context:

□ Answer needs specific details: contact info, phone, addresses, codes, dates
□ Content is time-sensitive: news, budgets, program updates, policy changes
□ URL or page title is unfamiliar to you
□ URL has date AFTER your training cutoff
□ URL has complex policy, regulations, requirements, laws, eligibility
□ Question matches "⚠️ TOOL-REQUIRED" trigger in department scenarios

MANDATORY ACTION:
• If ANY checkbox TRUE → Call downloadWebPage NOW for 1-2 most relevant URLs
• If ALL checkboxes FALSE → Proceed without download

Example tool usage:
{
  "tool": "downloadWebPage",
  "arguments": {
    "url": "https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/tax-return/completing-a-tax-return/deductions-credits-expenses/line-21900-moving-expenses.html"
  }
}
`;
```

**AI Reasoning (From Logs):**
```
[Question] "What are the moving expense deductions for 2024?"

[AI Thinking]
- Question asks for specific year (2024)
- Moving expenses likely have specific rules and amounts
- My training cutoff is April 2023, this is 2024 tax year
- Context has URL: canada.ca/...moving-expenses.html
- ✓ Time-sensitive content (tax year)
- ✓ Needs specific details (amounts, rules)
- ✓ After training cutoff

[AI Decision] I should download the page to get current 2024 information.

[Tool Call]
downloadWebPage({
  url: "https://www.canada.ca/...moving-expenses.html"
})

[Tool Result]
# Moving expenses deduction
## Eligible expenses for 2024
- Travel costs: ...
- Temporary living: max 15 days
- ... [detailed current info]

[AI Answer] Based on current CRA guidelines...
```

---

## Tool Tracking and Monitoring

**File:** `agents/ToolTrackingHandler.js`

```javascript
export class ToolTrackingHandler extends BaseCallbackHandler {
  constructor(chatId) {
    super();
    this.chatId = chatId;
    this.toolCalls = [];
  }
  
  async handleToolStart(tool, input) {
    const call = {
      tool: tool.name,
      input,
      startTime: Date.now()
    };
    
    this.toolCalls.push(call);
    
    await ServerLoggingService.info('Tool call started', this.chatId, {
      tool: tool.name,
      input
    });
  }
  
  async handleToolEnd(output) {
    const call = this.toolCalls[this.toolCalls.length - 1];
    call.endTime = Date.now();
    call.duration = call.endTime - call.startTime;
    call.output = output;
    call.success = true;
    
    await ServerLoggingService.info('Tool call completed', this.chatId, {
      tool: call.tool,
      duration: call.duration,
      success: true
    });
  }
  
  async handleToolError(error) {
    const call = this.toolCalls[this.toolCalls.length - 1];
    call.endTime = Date.now();
    call.duration = call.endTime - call.startTime;
    call.error = error.message;
    call.success = false;
    
    await ServerLoggingService.error('Tool call failed', this.chatId, {
      tool: call.tool,
      duration: call.duration,
      error: error.message
    });
  }
}
```

**Saved to Database:**
```javascript
// api/db/db-persist-interaction.js
await ToolUsage.create({
  interactionId,
  tools: toolTracker.toolCalls.map(call => ({
    name: call.tool,
    input: call.input,
    output: call.output,
    duration: call.duration,
    success: call.success,
    error: call.error,
    timestamp: call.startTime
  }))
});
```

**Dashboard View:**
```
Question: "What are the EI eligibility requirements?"
Tools Used:
  ✓ downloadWebPage
    URL: https://www.canada.ca/ei-eligibility.html
    Duration: 1,234ms
    Output: 1,456 tokens
  
  ✓ checkUrlStatus  
    URL: https://www.canada.ca/ei-eligibility.html
    Duration: 145ms
    Result: Valid (200)

Total Tool Time: 1,379ms (15% of total response time)
```

---

## EVA Implementation Guide

### Python LangChain Tools

```python
from langchain.tools import tool
from langchain_core.tools import StructuredTool
import requests
from bs4 import BeautifulSoup
import markdown

@tool
def download_web_page(url: str) -> str:
    """
    Download and parse a web page for current information.
    
    Use this tool to:
    - Verify current legislation or case law
    - Get specific details from official sources
    - Check time-sensitive legal content
    - Validate unfamiliar URLs
    
    Args:
        url: Full URL to download and parse
        
    Returns:
        Markdown-formatted content of the page
    """
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        # Parse HTML
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Extract main content
        main_content = soup.find('main') or soup.find('body')
        
        # Convert to markdown
        # (implement HTML to Markdown conversion)
        markdown_content = html_to_markdown(main_content)
        
        return markdown_content
        
    except Exception as e:
        raise ValueError(f"Failed to download {url}: {str(e)}")

@tool
def check_url_status(url: str) -> dict:
    """
    Check if a URL is accessible before citing it.
    
    Args:
        url: URL to validate
        
    Returns:
        Dictionary with status information
    """
    try:
        response = requests.head(url, timeout=10, allow_redirects=True)
        return {
            "is_valid": response.status_code < 400,
            "status": response.status_code,
            "final_url": response.url
        }
    except Exception as e:
        return {
            "is_valid": False,
            "error": str(e)
        }

# Create agent with tools
from langgraph.prebuilt import create_react_agent

tools = [download_web_page, check_url_status]

agent = create_react_agent(
    model=llm,
    tools=tools,
    state_modifier=system_prompt
)
```

---

**Next:** [05-AGENT-ORCHESTRATION.md](05-AGENT-ORCHESTRATION.md) for orchestration patterns and [07-EVA-COMPARISON.md](07-EVA-COMPARISON.md) for detailed comparison with EVA architecture.
