# AI Answers Agentic Architecture Analysis

**Date:** February 7, 2026  
**Source Repository:** [cds-snc/ai-answers](https://github.com/cds-snc/ai-answers)  
**Purpose:** Analyze the CDS-SNC AI Answers architecture for patterns applicable to EVA Jurisprudence

---

## Overview

AI Answers is a production Government of Canada AI assistant running at https://ai-answers.alpha.canada.ca. It represents a **next-generation agentic chat architecture** using LangGraph state machines, autonomous tool-using agents, and sophisticated evaluation systems.

### Why Study This Architecture?

1. **Production-Proven**: Live on Canada.ca serving real government users
2. **Agentic Capabilities**: AI autonomously uses tools to verify and enhance accuracy
3. **LangGraph State Machine**: Modern orchestration pattern with clear state management
4. **Privacy-First**: Multi-stage PI detection and blocking
5. **Evaluation-Driven**: Continuous human + AI evaluation loop
6. **Model-Independent**: Works with OpenAI, Azure, Anthropic
7. **Department-Specific**: Customizable prompts per government department (applicable to jurisprudence domains)

### Key Innovation: Autonomous Tool Usage

Unlike traditional chat systems that only query vector stores, AI Answers agents **autonomously decide** when to:
- Download and parse current web pages for verification
- Re-derive context if initial results insufficient
- Validate URLs before returning them
- Use specialized department-specific tools

This is **critical for legal/jurisprudence applications** where accuracy and currency of information are paramount.

---

## Documentation Structure

1. **[01-EXECUTIVE-SUMMARY.md](01-EXECUTIVE-SUMMARY.md)** - High-level overview and key takeaways
2. **[02-ARCHITECTURE-DEEP-DIVE.md](02-ARCHITECTURE-DEEP-DIVE.md)** - Complete technical architecture
3. **[03-LANGGRAPH-PIPELINE.md](03-LANGGRAPH-PIPELINE.md)** - 9-step pipeline detailed breakdown
4. **[04-AGENTIC-TOOLS.md](04-AGENTIC-TOOLS.md)** - Tool usage patterns and implementation
5. **[05-AGENT-ORCHESTRATION.md](05-AGENT-ORCHESTRATION.md)** - AgentOrchestrator pattern analysis
6. **[06-PROMPT-ENGINEERING.md](06-PROMPT-ENGINEERING.md)** - System prompts and scenarios
7. **[07-EVA-COMPARISON.md](07-EVA-COMPARISON.md)** - Side-by-side comparison with EVA architecture
8. **[08-INTEGRATION-PLAN.md](08-INTEGRATION-PLAN.md)** - Recommendations for EVA enhancement
9. **[09-CODE-PATTERNS.md](09-CODE-PATTERNS.md)** - Reusable code patterns and templates
10. **[10-EVALUATION-SYSTEM.md](10-EVALUATION-SYSTEM.md)** - Continuous evaluation framework

---

## Quick Reference

### Technology Stack

| Component | AI Answers | EVA Current |
|-----------|-----------|-------------|
| **Frontend** | React + Canada.ca Design System | React + Custom UI |
| **Backend** | Node.js + Express | Python + Quart/Flask |
| **Orchestration** | LangGraph State Machine | Sequential Python functions |
| **AI Models** | Azure OpenAI GPT-4.1, GPT-4o Mini | Azure OpenAI GPT-4 |
| **Database** | MongoDB (AWS DocumentDB) | Azure Cosmos DB |
| **Search** | Canada.ca + Google | Azure AI Search |
| **Vector Store** | MongoDB Atlas Vector Search | Azure AI Search Vector |
| **Infrastructure** | AWS (Terraform/Terragrunt) | Azure (Bicep) |

### Key Architectural Differences

| Aspect | AI Answers | EVA |
|--------|-----------|-----|
| **Pipeline** | LangGraph state machine (9 steps) | Sequential request handlers |
| **Tool Usage** | Autonomous agent decisions | Predefined search queries |
| **Context** | Dynamic per-question derivation | Vector search + predefined chunks |
| **Evaluation** | Continuous human + AI loop | Manual spot checks |
| **Privacy** | Two-stage PI blocking | Basic input validation |
| **Citation** | Programmatic URL verification | AI-generated links |
| **Status Updates** | Real-time SSE streaming | Single response |
| **State Management** | Immutable state graph | Mutable request context |

### Critical Files to Study

**LangGraph Pipeline:**
- `C:\AICOE\ai-answers\agents\graphs\DefaultWithVectorGraph.js` - Main graph definition
- `C:\AICOE\ai-answers\docs\architecture\pipeline-architecture.md` - Complete documentation

**Agent Orchestration:**
- `C:\AICOE\ai-answers\agents\AgentOrchestratorService.js` - Orchestrator pattern
- `C:\AICOE\ai-answers\agents\AgentFactory.js` - Agent factory pattern

**Agentic Tools:**
- `C:\AICOE\ai-answers\agents\tools\downloadWebPage.js` - Web scraping for verification
- `C:\AICOE\ai-answers\agents\tools\contextAgentTool.js` - Context re-derivation

**Prompts:**
- `C:\AICOE\ai-answers\agents\prompts\agenticBase.js` - 7-step instruction framework
- `C:\AICOE\ai-answers\agents\prompts\scenarios\` - Department-specific prompts

---

## Applicability to EVA Jurisprudence

### High-Priority Patterns to Adopt

1. **✅ Autonomous Web Scraping** - Download current case law/legislation for verification
2. **✅ LangGraph State Machine** - Clear orchestration with error handling
3. **✅ Citation Verification** - Programmatic URL validation before returning
4. **✅ Short-Circuit Optimization** - Vector similarity to reuse previous answers
5. **✅ Department/Court-Specific Scenarios** - Customizable prompts per jurisdiction
6. **✅ Real-Time Status Updates** - SSE streaming for long operations

### Medium-Priority Patterns

7. **⚡ Agent Orchestration Service** - Strategy pattern for different agent types
8. **⚡ Tool Tracking Handler** - Monitor all tool invocations
9. **⚡ Context Reuse** - Avoid re-deriving context for follow-up questions
10. **⚡ Confidence Scoring** - 0-10 rating for answer quality

### Considerations for EVA

- **Language Difference**: AI Answers is Node.js, EVA is Python
  - LangGraph available in Python: `pip install langgraph`
  - Tool patterns directly translatable
  - State machine concepts identical

- **Infrastructure**: AI Answers uses AWS, EVA uses Azure
  - Core patterns infrastructure-agnostic
  - Azure equivalents exist for all services

- **Domain Specificity**: AI Answers serves general government info, EVA serves legal
  - Legal domain requires even stricter accuracy (tool usage more critical)
  - Citation verification essential for case law
  - Department scenarios → Court/jurisdiction scenarios

---

## Next Steps

1. **Read Executive Summary** ([01-EXECUTIVE-SUMMARY.md](01-EXECUTIVE-SUMMARY.md)) for key insights
2. **Study Architecture** ([02-ARCHITECTURE-DEEP-DIVE.md](02-ARCHITECTURE-DEEP-DIVE.md)) for technical details
3. **Review EVA Comparison** ([07-EVA-COMPARISON.md](07-EVA-COMPARISON.md)) for specific gaps
4. **Plan Integration** ([08-INTEGRATION-PLAN.md](08-INTEGRATION-PLAN.md)) for phased implementation

---

## References

- **AI Answers Production:** https://ai-answers.alpha.canada.ca
- **Source Code:** https://github.com/cds-snc/ai-answers
- **System Card:** [C:\AICOE\ai-answers\SYSTEM_CARD.md](C:\AICOE\ai-answers\SYSTEM_CARD.md)
- **Pipeline Docs:** [C:\AICOE\ai-answers\docs\architecture\pipeline-architecture.md](C:\AICOE\ai-answers\docs\architecture\pipeline-architecture.md)
- **LangGraph Docs:** https://langchain-ai.github.io/langgraph/

---

**Maintained by:** EVA Architecture Team  
**Last Updated:** February 7, 2026
