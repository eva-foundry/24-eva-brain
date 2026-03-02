# RAG Test Bench Architecture - Netflix-Style A/B Testing for Enterprise AI

**Date**: February 7, 2026  
**Purpose**: Architectural strategy for separating monolithic EVA-JP and implementing Netflix-style A/B testing infrastructure for RAG quality validation  
**Source System**: EVA-Jurisprudence-SecMode-Info-Assistant v1.2 (Production: EsPAICoESub)

---

## Executive Summary

**Strategic Goal**: Transform monolithic RAG application into independently deployable microservices with Netflix-style A/B testing infrastructure to enable:
- UAT developers to submit golden questions for continuous RAG validation
- Automated comparison of different RAG approaches with statistical confidence
- Progressive rollout of RAG improvements with automatic rollback on regression
- Enterprise-grade quality gates preventing bad deployments

**Timeline**: Phased 5-week implementation  
**Primary Use Case**: RAG Test Bench for golden question validation and approach comparison

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Target Architecture](#target-architecture)
3. [Separation Strategy](#separation-strategy)
4. [Netflix-Style A/B Testing](#netflix-style-ab-testing)
5. [Implementation Patterns](#implementation-patterns)
6. [Phased Implementation Plan](#phased-implementation-plan)
7. [Code Examples](#code-examples)

---

## Current State Analysis

### Monolithic Architecture (EVA-JP v1.2)

```
┌─────────────────────────────────────────────────────────────┐
│ marco-sandbox-backend (MONOLITHIC - Backend + Frontend)    │
│ https://marco-sandbox-backend.azurewebsites.net            │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │  FastAPI Backend (Python)                               │ │
│ │  - Line 2337: app.mount("/", StaticFiles(directory=...))│ │
│ │  - 34 API endpoints (/chat, /sessions, /upload, etc.)  │ │
│ │  - RAG approaches: chatreadretrieveread, chatwebretrie..│ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │  React Frontend (Vite/TypeScript)                       │ │
│ │  - vite.config.ts: outDir="../backend/static"           │ │
│ │  - 30+ API client functions in api.ts                   │ │
│ │  - Built into /home/site/wwwroot/static/                │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  Single Docker image, single deployment, single scaling    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ marco-sandbox-enrichment (Document Processing)              │
│ https://marco-sandbox-enrichment.azurewebsites.net          │
│ - Python enrichment service                                 │
│ - Handles document ingestion and processing                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ marco-sandbox-func (Background Jobs)                        │
│ https://marco-sandbox-func.azurewebsites.net                │
│ - Azure Functions (containerized)                           │
│ - Background processing tasks                               │
└─────────────────────────────────────────────────────────────┘
```

### Key Components Discovered

**Backend API Endpoints (34 total)**:
- Core RAG: `/chat`, `/getcitation`, `/gettags`, `/getfolders`
- Assistants: `/posttd`, `/process_agent_response`, `/getTdAnalysis`
- Document Management: `/file`, `/get-file`, `/getalluploadstatus`, `/deleteItems`, `/resubmitItems`
- User Management: `/getUsrGroupInfo`, `/updateUsrGroupInfo`
- Web Integration: `/urlscrapper`, `/urlscrapperpreview`, `/translate-file`
- Sessions: `/sessions/*` (router-based)

**RAG Approaches (in approaches/ directory)**:
- `chatreadretrieveread.py` - Deep RAG with retrieval
- `chatwebretrieveread.py` - Web-augmented RAG
- `comparewebwithwork.py` - Work vs Web comparison
- `compareworkwithweb.py` - Web vs Work comparison
- `gpt_direct_approach.py` - Direct GPT-4 (no RAG)
- `mathassistant.py` - Math-focused assistant
- `tabulardataassistant.py` - Data analysis assistant

**Frontend API Client**:
- 30 exported functions in `api.ts`
- All use relative paths: `fetch("/chat", ...)`, `fetch("/sessions", ...)`
- No environment-based API URL configuration (tightly coupled)

### Problems with Current Architecture

| Issue | Impact | Severity |
|-------|--------|----------|
| **Frontend build failures block backend deployment** | Can't deploy API fixes independently | 🔴 Critical |
| **Cannot scale backend independently** | Waste resources scaling unused frontend | 🟡 Medium |
| **No A/B testing infrastructure** | Can't validate RAG improvements scientifically | 🔴 Critical |
| **Monolithic = single point of failure** | One bad endpoint crashes entire service | 🟡 Medium |
| **Test workloads impact production** | Golden question testing degrades user experience | 🔴 Critical |
| **Cannot version APIs independently** | Breaking changes require frontend redeployment | 🟡 Medium |

**Current Issue Experienced**:
```
❌ Frontend returns 404 - no static files in deployed container
✅ Backend APIs functional at /api/* endpoints
⚠️  Probably caused by frontend build failure during Docker build
```

---

## Target Architecture

### Three-Service Microservices with Test Bench

```
┌──────────────────────────────────────────────────────────────────┐
│                    AZURE FRONT DOOR / APIM                       │
│              (API Gateway + Authentication Layer)                │
└────────────────────┬─────────────────────────────────────────────┘
                     │
    ┌────────────────┼────────────────┬──────────────────┐
    │                │                │                  │
    ▼                ▼                ▼                  ▼
┌─────────┐   ┌──────────────┐   ┌────────────────┐   ┌──────────┐
│Frontend │   │  RAG Core    │   │  Test Bench    │   │Enrichment│
│Static   │   │  APIs        │   │  APIs (NEW)    │   │ Service  │
│Web App  │   │              │   │                │   │          │
│         │   │ /api/rag/*   │   │/api/testbench/*│   │          │
└─────────┘   └──────────────┘   └────────────────┘   └──────────┘
    │              │                    │                    │
    │              │                    │                    │
    │              ▼                    ▼                    ▼
    │         ┌──────────────────────────────────────────────────┐
    │         │          SHARED SERVICES LAYER                   │
    │         │  - Azure AI Search (RAG retrieval)               │
    │         │  - Azure OpenAI (GPT-4o, embeddings)             │
    │         │  - CosmosDB (sessions, test results, golden Q's) │
    │         │  - Blob Storage (documents, evidence)            │
    │         │  - Application Insights (telemetry)              │
    │         └──────────────────────────────────────────────────┘
    │
    └──────────────────────┐
                          │
                     ┌────▼─────────┐
                     │  Users       │
                     │  (Browser)   │
                     └──────────────┘
```

### Service Responsibilities

#### 1. Frontend (Azure Static Web Apps)
- **Technology**: React 18 + Vite + TypeScript
- **Deployment**: Azure Static Web Apps or CDN + Storage
- **Responsibilities**:
  - User interface for chat, document management
  - Test bench UI for UAT developers
  - Real-time experiment dashboards
- **API Communication**: Environment-based URLs
  ```typescript
  const API_ENDPOINTS = {
    RAG: process.env.VITE_RAG_API_URL,
    TESTBENCH: process.env.VITE_TESTBENCH_API_URL
  }
  ```

#### 2. RAG Core APIs (Azure App Service)
- **Technology**: Python FastAPI + Quart (async)
- **Deployment**: Azure App Service (Linux Container) or AKS
- **Responsibilities**:
  - Chat API (`/api/rag/chat`)
  - RAG approaches (7 different approaches)
  - Document Q&A with citations
  - Session management
  - User profile management
- **Endpoints**:
  ```
  POST /api/rag/chat
  GET  /api/rag/health
  POST /api/rag/getcitation
  GET  /api/rag/getalltags
  POST /api/rag/sessions
  ```

#### 3. Test Bench APIs (Azure App Service - NEW)
- **Technology**: Python FastAPI
- **Deployment**: Azure App Service or Azure Functions
- **Responsibilities**:
  - Golden question management
  - A/B test execution
  - Statistical analysis
  - Progressive rollout automation
  - Evidence collection
- **Endpoints**:
  ```
  POST /api/testbench/golden-questions
  POST /api/testbench/test-runs
  GET  /api/testbench/test-runs/{id}
  POST /api/testbench/ab-test
  GET  /api/testbench/compare/{run1}/{run2}
  ```

#### 4. Enrichment Service (Existing)
- **Technology**: Flask + Azure Functions
- **Deployment**: Already deployed separately
- **Responsibilities**:
  - Document OCR (Form Recognizer)
  - Text chunking
  - Embeddings generation
  - Azure Search indexing

---

## Separation Strategy

### Pros & Cons Analysis

#### ❌ Current Monolithic Architecture

**Pros:**
- ✅ Simple deployment (one container)
- ✅ No network latency between frontend/backend
- ✅ Easier local development
- ✅ Single authentication boundary

**Cons:**
- ❌ **Frontend build failures block entire deployment** (your current issue!)
- ❌ Cannot scale backend independently from frontend
- ❌ One bad endpoint crashes entire service
- ❌ Cannot version APIs independently
- ❌ Difficult to add new features without touching core
- ❌ **No way to A/B test different RAG approaches separately**
- ❌ Test bench workloads impact production RAG performance

#### ✅ Separated Architecture

**Pros:**
- ✅ **Frontend deploy failures don't affect backend APIs**
- ✅ Independent scaling (scale RAG APIs heavy, test bench light)
- ✅ **Test bench can hammer APIs without affecting production users**
- ✅ Can deploy new test bench features without touching RAG core
- ✅ **Multiple RAG API versions running simultaneously** (v1, v2, canary)
- ✅ Better observability (separate Application Insights per service)
- ✅ Enables A/B testing of RAG approaches
- ✅ **Frontend served from CDN = faster global performance**
- ✅ Easier team collaboration (frontend team vs backend team vs test team)
- ✅ **Can add rate limiting per service** (protect RAG from test bench abuse)
- ✅ **Netflix-style progressive rollout with automatic rollback**

**Cons:**
- ❌ More infrastructure to maintain (3+ services vs 1)
- ❌ Network latency between services (mitigated by Azure backbone)
- ❌ Slightly more complex local development
- ❌ Need API Gateway / APIM for routing
- ❌ Distributed tracing more complex
- ❌ Authentication must work across services

**Verdict**: **Separated architecture is significantly better** for enterprise RAG with test bench requirements.

---

## Netflix-Style A/B Testing

### Core Concept

**Traditional Deployment:**
```
Old Version → Deploy New Version → Hope it works better → Rollback if users complain
```

**Netflix A/B Testing:**
```
50% users → Version A (current RAG approach)
50% users → Version B (new RAG approach)
↓
Measure: Quality, Latency, Cost, User Satisfaction
↓
Winner deployed to 100% automatically based on statistical significance
```

### Key Principles

#### 1. Traffic Splitting with Consistent Hashing

```python
def route_rag_request(question_id: str, experiment: dict):
    """Route golden questions to RAG variants consistently"""
    
    # Consistent hashing - same question always tests same variant
    hash_value = hash(question_id) % 100
    
    cumulative = 0
    for variant_name, config in experiment["variants"].items():
        cumulative += config["traffic"] * 100
        if hash_value < cumulative:
            return variant_name, config
    
    # Fallback to control
    return "control", experiment["variants"]["control"]

# Example experiment
experiment = {
    "id": "rag-temperature-test",
    "variants": {
        "control": {
            "approach": "chatreadretrieveread",
            "overrides": {"temperature": 0.3},
            "traffic": 0.5  # 50%
        },
        "treatment": {
            "approach": "chatreadretrieveread",
            "overrides": {"temperature": 0.5},
            "traffic": 0.5  # 50%
        }
    }
}
```

#### 2. Statistical Significance Analysis

```python
import scipy.stats as stats
import numpy as np

class ABTestAnalyzer:
    """Determine winning RAG approach with statistical confidence"""
    
    def analyze_experiment(self, experiment_results: list) -> dict:
        """
        Run t-test to determine if treatment is significantly better
        
        Returns decision with confidence level
        """
        # Separate results by variant
        control_scores = [r["score"] for r in experiment_results if r["variant"] == "control"]
        treatment_scores = [r["score"] for r in experiment_results if r["variant"] == "treatment"]
        
        # Statistical test
        t_stat, p_value = stats.ttest_ind(control_scores, treatment_scores)
        
        control_mean = np.mean(control_scores)
        treatment_mean = np.mean(treatment_scores)
        
        # Decision criteria: p < 0.05 and improvement > 0
        is_significant = p_value < 0.05
        is_improvement = treatment_mean > control_mean
        
        if is_significant and is_improvement:
            improvement_pct = ((treatment_mean - control_mean) / control_mean) * 100
            
            return {
                "winner": "treatment",
                "confidence": f"{(1 - p_value) * 100:.1f}%",
                "improvement": f"+{improvement_pct:.1f}%",
                "recommendation": "DEPLOY_TO_100_PERCENT",
                "details": {
                    "control_mean": control_mean,
                    "treatment_mean": treatment_mean,
                    "p_value": p_value,
                    "sample_size": len(control_scores)
                }
            }
        else:
            return {
                "winner": "control",
                "confidence": f"{(1 - p_value) * 100:.1f}%",
                "recommendation": "KEEP_CURRENT_VERSION",
                "reason": "No statistically significant improvement"
            }
```

#### 3. Progressive Rollout with Automatic Rollback

```python
class ProgressiveRollout:
    """Netflix-style canary deployment for RAG approaches"""
    
    async def execute_rollout(self, new_approach: str, baseline_approach: str):
        """
        Gradually deploy new RAG approach with automatic rollback
        
        Stages: 1% → 5% → 25% → 50% → 100%
        Monitors: Quality score, latency, cost
        Rollback: Automatic if quality drops > 5%
        """
        
        rollout_stages = [
            {"traffic": 0.01, "duration_hours": 24, "min_queries": 100},
            {"traffic": 0.05, "duration_hours": 24, "min_queries": 500},
            {"traffic": 0.25, "duration_hours": 48, "min_queries": 2000},
            {"traffic": 0.50, "duration_hours": 48, "min_queries": 5000},
            {"traffic": 1.00, "duration_hours": 0, "min_queries": 0}
        ]
        
        baseline_quality = await self.get_baseline_quality(baseline_approach)
        
        for stage in rollout_stages:
            # Update traffic split
            await self.set_traffic_split({
                "baseline": 1 - stage["traffic"],
                "canary": stage["traffic"]
            })
            
            # Monitor during stage
            canary_metrics = await self.monitor_stage(
                duration_hours=stage["duration_hours"],
                min_queries=stage["min_queries"]
            )
            
            # Quality gate: rollback if regression > 5%
            quality_threshold = baseline_quality * 0.95
            
            if canary_metrics["quality_score"] < quality_threshold:
                await self.rollback_deployment()
                
                await self.alert_team({
                    "status": "ROLLED_BACK",
                    "stage": f"{stage['traffic']*100}%",
                    "reason": "Quality regression detected",
                    "canary_quality": canary_metrics["quality_score"],
                    "baseline_quality": baseline_quality,
                    "threshold": quality_threshold
                })
                
                return {"status": "FAILED", "stage": stage}
            
            # Stage passed
            self.log_stage_success(stage, canary_metrics)
        
        # All stages passed
        return {"status": "DEPLOYED", "confidence": "HIGH"}
```

#### 4. Real-Time Metrics Dashboard

**Key Metrics to Monitor**:
- **Quality Score**: Answer accuracy vs golden questions
- **Citation Accuracy**: % of correct citations provided
- **Latency (P95)**: 95th percentile response time
- **Cost Per Query**: Azure OpenAI token costs
- **Error Rate**: % of failed requests

**Dashboard Components**:
```typescript
// Real-time A/B test monitoring
interface ExperimentMetrics {
  control: {
    quality_score: number;      // 0.0 - 1.0
    latency_p95_ms: number;      // milliseconds
    cost_per_query: number;      // USD
    citation_accuracy: number;   // 0.0 - 1.0
    error_rate: number;          // 0.0 - 1.0
    sample_size: number;
  };
  treatment: {
    quality_score: number;
    latency_p95_ms: number;
    cost_per_query: number;
    citation_accuracy: number;
    error_rate: number;
    sample_size: number;
  };
  statistical_analysis: {
    p_value: number;
    confidence: string;
    winner: "control" | "treatment" | "inconclusive";
    recommendation: string;
  };
}
```

### Why Netflix Approach is Revolutionary

| Traditional Testing | Netflix A/B Testing |
|---------------------|---------------------|
| Deploy → Hope → Rollback if broken | Deploy to 1% → Measure → Auto-rollout if better |
| Gut feeling decisions | Data-driven with statistical confidence |
| Manual rollback after complaints | Automatic rollback before users notice |
| One metric (uptime) | Dozens of metrics (quality, latency, cost) |
| Quarterly releases | Hundreds of experiments running simultaneously |
| High risk deployments | De-risked progressive rollout |

### Applied to RAG Test Bench

**Example Experiment: Temperature Parameter Tuning**

```python
# Hypothesis: Higher temperature (0.5) provides more helpful answers than 0.3

experiment = {
    "id": "rag-temperature-2026-02-07",
    "hypothesis": "temperature=0.5 improves answer quality",
    "variants": {
        "control": {
            "approach": "chatreadretrieveread",
            "overrides": {"temperature": 0.3, "top": 5}
        },
        "treatment": {
            "approach": "chatreadretrieveread",
            "overrides": {"temperature": 0.5, "top": 5}
        }
    },
    "primary_metric": "quality_score",
    "secondary_metrics": ["latency_ms", "citation_accuracy"],
    "guardrail_metrics": {
        "cost_per_query": {"max": 0.20},
        "latency_p95": {"max": 5000}
    },
    "sample_size": 1000,  # Golden questions per variant
    "duration": "7 days"
}

# Execute experiment
results = await run_ab_test(experiment)

# Results after 1000 golden questions per variant
{
  "winner": "treatment",
  "improvement": "+8.5% quality score",
  "confidence": "99.2%",
  "p_value": 0.008,
  "recommendation": "DEPLOY_TO_100_PERCENT",
  "reasoning": [
    "Treatment scored 0.87 vs Control 0.80 (highly significant)",
    "Latency unchanged: 4.2s vs 4.1s (p=0.42)",
    "Cost within guardrails: $0.16 < $0.20",
    "No negative impact on citations: 92% vs 91%"
  ],
  "deployment_plan": "Progressive rollout starting at 1%"
}
```

**Automated Progressive Deployment:**
```
Day 1: Deploy temp=0.5 to 1% of questions → Quality maintained
Day 2: Increase to 5% → Still better
Day 3: Increase to 25% → Cost acceptable
Day 4: Increase to 50% → Latency acceptable  
Day 5: Deploy to 100% → New default
```

---

## Implementation Patterns

### Pattern 1: EVA Face - Universal API Gateway

**Concept**: Single API gateway intelligently routes to different backends based on context

```python
from fastapi import FastAPI, Request
import httpx

app = FastAPI(title="EVA Face - API Gateway")

# Backend endpoints
BACKENDS = {
    "rag_v1": "https://marco-sandbox-backend.azurewebsites.net",
    "rag_v2": "https://marco-sandbox-backend-v2.azurewebsites.net",
    "testbench": "https://marco-sandbox-testbench.azurewebsites.net"
}

@app.post("/api/chat")
async def intelligent_routing(request: Request):
    """Route chat requests to appropriate backend"""
    data = await request.json()
    
    # Routing logic
    if data.get("is_test_mode"):
        backend_url = BACKENDS["testbench"]
    elif data.get("use_experimental"):
        backend_url = BACKENDS["rag_v2"]
    else:
        backend_url = BACKENDS["rag_v1"]
    
    # Proxy request
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{backend_url}/chat",
            json=data,
            headers={
                "x-ms-client-principal-id": request.headers.get("x-ms-client-principal-id")
            },
            timeout=30.0
        )
    
    return response.json()

@app.get("/api/health")
async def aggregate_health():
    """Aggregate health from all backends"""
    health_status = {}
    
    for name, url in BACKENDS.items():
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{url}/health", timeout=5.0)
                health_status[name] = "healthy" if response.status_code == 200 else "unhealthy"
        except:
            health_status[name] = "unreachable"
    
    return {
        "status": "healthy" if all(s == "healthy" for s in health_status.values()) else "degraded",
        "backends": health_status
    }
```

**Value**: Clients don't know or care which backend serves them - gateway handles complexity

### Pattern 2: Client SDK Pattern

**Create unified SDK for test bench clients:**

```typescript
// eva-testbench-sdk/client.ts

export class EVATestBenchClient {
    constructor(private config: {
        baseUrl: string;
        getAuthToken: () => Promise<string>;
    }) {}
    
    // High-level API for UAT developers
    async submitGoldenQuestion(question: GoldenQuestion): Promise<string> {
        return this.post("/api/testbench/golden-questions", question);
    }
    
    async runTestSuite(suiteId: string, options?: TestRunOptions): Promise<TestRun> {
        return this.post("/api/testbench/test-runs", { 
            test_suite: suiteId,
            ...options 
        });
    }
    
    async compareApproaches(
        questionId: string, 
        approaches: string[]
    ): Promise<ComparisonResult> {
        return this.post("/api/testbench/compare", { 
            questionId, 
            approaches 
        });
    }
    
    // Real-time streaming for long tests
    streamTestProgress(runId: string): EventSource {
        return new EventSource(
            `${this.config.baseUrl}/api/testbench/runs/${runId}/stream`
        );
    }
    
    private async post(path: string, data: any): Promise<any> {
        const token = await this.config.getAuthToken();
        const response = await fetch(`${this.config.baseUrl}${path}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${token}`
            },
            body: JSON.stringify(data)
        });
        
        if (!response.ok) {
            throw new Error(`API error: ${response.statusText}`);
        }
        
        return response.json();
    }
}

// Usage by UAT developers
const testBench = new EVATestBenchClient({
    baseUrl: "https://marco-sandbox-testbench.azurewebsites.net",
    getAuthToken: async () => await getEntraIDToken()
});

// Submit golden question
await testBench.submitGoldenQuestion({
    question: "What is maximum EI benefit duration?",
    expectedAnswer: "45 weeks for regular benefits",
    expectedCitations: ["EI-ACT-SECTION-12"],
    testSuite: "ei-benefits-2026"
});

// Run test suite comparing 3 approaches
const run = await testBench.runTestSuite("ei-benefits-2026", {
    approaches: ["chatreadretrieveread", "chatwebretrieveread", "gpt_direct"],
    parallel: true
});
```

**Value**: UAT developers use simple API, no need to understand backend complexity

### Pattern 3: Evidence Collection for Audit Trails

```python
class TestEvidenceCollector:
    """Comprehensive test artifact collection for compliance"""
    
    async def execute_with_evidence(self, test_run: TestRun):
        """Capture everything for audit/debugging"""
        
        evidence_dir = f"runs/test-runs/{test_run.id}/evidence/"
        
        for question in test_run.questions:
            # Capture request
            await self.save_artifact(
                f"{evidence_dir}/{question.id}_request.json",
                json.dumps({
                    "question": question.question,
                    "approach": test_run.approach,
                    "overrides": test_run.overrides,
                    "timestamp": datetime.utcnow().isoformat()
                }, indent=2)
            )
            
            # Execute RAG
            response = await self.execute_rag(question, test_run.approach, test_run.overrides)
            
            # Capture response
            await self.save_artifact(
                f"{evidence_dir}/{question.id}_response.json",
                json.dumps(response, indent=2)
            )
            
            # Capture citations for verification
            for i, citation in enumerate(response.get("citations", [])):
                doc_content = await self.fetch_citation_document(citation)
                await self.save_artifact(
                    f"{evidence_dir}/{question.id}_citation_{i}_{citation}.txt",
                    doc_content
                )
            
            # Generate semantic diff
            if question.expected_answer:
                diff = self.generate_semantic_diff(
                    expected=question.expected_answer,
                    actual=response["answer"]
                )
                await self.save_artifact(
                    f"{evidence_dir}/{question.id}_diff.html",
                    self.render_diff_html(diff)
                )
        
        # Generate test report
        await self.generate_test_report(test_run, evidence_dir)
```

**Stored Artifacts Structure:**
```
runs/test-runs/run-20260207-140530/
├── evidence/
│   ├── q1_request.json
│   ├── q1_response.json
│   ├── q1_citation_0_EI-ACT-12.txt
│   ├── q1_citation_1_EI-GUIDE-5.txt
│   ├── q1_diff.html
│   ├── q2_request.json
│   └── ...
├── screenshots/           # Future: Playwright UI captures
├── performance/
│   ├── latency_profile.json
│   └── token_usage.json
└── TEST-RUN-REPORT.md
```

**Value**: Full audit trail for compliance, complete debugging context

### Pattern 4: Configuration-Driven Approach Selection

```json
// configs/testbench-strategies.json
{
  "rag_approaches": {
    "chatreadretrieveread": {
      "name": "Deep RAG with Retrieval",
      "best_for": ["complex_legal", "citation_heavy", "multi_document"],
      "overrides": {
        "top": 5,
        "semantic_ranker": true,
        "temperature": 0.3
      },
      "cost_per_query": 0.15,
      "avg_latency_ms": 4500,
      "quality_baseline": 0.82
    },
    "chatwebretrieveread": {
      "name": "Web-Augmented RAG",
      "best_for": ["recent_updates", "external_context"],
      "overrides": {
        "top": 3,
        "use_bing": true,
        "temperature": 0.5
      },
      "cost_per_query": 0.25,
      "avg_latency_ms": 6000,
      "quality_baseline": 0.78
    },
    "gpt_direct": {
      "name": "Direct GPT-4 (No RAG)",
      "best_for": ["general_knowledge", "reasoning"],
      "overrides": {
        "byPassRAG": true,
        "temperature": 0.7
      },
      "cost_per_query": 0.05,
      "avg_latency_ms": 2000,
      "quality_baseline": 0.65
    }
  },
  
  "test_suites": {
    "ei-benefits-2026": {
      "description": "Employment Insurance benefits questions",
      "recommended_approach": "chatreadretrieveread",
      "quality_threshold": 0.85,
      "max_latency_ms": 5000,
      "golden_questions": [
        "ei-001", "ei-002", "ei-003"
      ]
    },
    "general-knowledge": {
      "description": "General questions not requiring documents",
      "recommended_approach": "gpt_direct",
      "quality_threshold": 0.75,
      "max_latency_ms": 3000
    }
  }
}
```

**Value**: Data-driven approach selection, easy to add new strategies, cost/performance tracking

### Pattern 5: Smoke Test Pattern for CI/CD Gates

```python
class RAGRegressionTest:
    """Continuous validation of RAG quality - blocks bad deployments"""
    
    async def run_smoke_suite(self) -> bool:
        """
        Run critical golden questions before deployment
        Returns: True if quality gate passes, False blocks deployment
        """
        
        critical_questions = await self.get_critical_questions()
        
        results = []
        for q in critical_questions:
            result = await self.test_question(q)
            results.append(result)
            
            # Fail fast on critical regression
            if result["score"] < q["min_score"]:
                logger.error(
                    f"REGRESSION DETECTED: {q['question']} "
                    f"scored {result['score']:.2f} < {q['min_score']:.2f}"
                )
                return False
        
        avg_score = sum(r["score"] for r in results) / len(results)
        
        # Gate deployment on quality threshold
        passed = avg_score >= 0.85
        
        if passed:
            logger.info(f"✅ QUALITY GATE PASSED: Avg score {avg_score:.2f}")
        else:
            logger.error(f"❌ QUALITY GATE FAILED: Avg score {avg_score:.2f} < 0.85")
        
        return passed
    
    async def get_critical_questions(self):
        """Questions that MUST always work"""
        return [
            {
                "id": "critical-001",
                "question": "What is Employment Insurance?",
                "min_score": 0.9,
                "max_latency_ms": 3000
            },
            {
                "id": "critical-002",
                "question": "How do I apply for EI benefits?",
                "min_score": 0.85,
                "required_citations": ["EI-APPLICATION-GUIDE"]
            }
        ]

# Azure DevOps Pipeline integration
# azure-pipelines.yml
# - script: |
#     python -m testbench.smoke_tests
#   displayName: 'RAG Quality Gate'
#   condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
#   continueOnError: false  # BLOCK deployment if fails
```

**Value**: Prevents bad RAG deployments from reaching production automatically

---

## Phased Implementation Plan

### Phase 1: Quick Win - Fix Current Issue (Week 1)

**Goal**: Restore frontend functionality in monolithic app

**Tasks**:
1. Add build verification to Dockerfile
2. Fix frontend build in container
3. Redeploy working monolithic app

**Deliverables**:
- ✅ Frontend serves from `/` successfully
- ✅ Backend APIs functional at `/api/*`
- ✅ Build verification prevents future 404 issues

**Effort**: 1-2 days

---

### Phase 2: Extract Frontend (Week 2)

**Goal**: Deploy frontend to Azure Static Web Apps independently

**Tasks**:
1. Update `vite.config.ts` to output to `dist/` instead of `../backend/static`
2. Add environment-based API URL configuration
3. Deploy to Azure Static Web Apps
4. Update backend to remove `app.mount("/", StaticFiles(...))`
5. Configure CORS on backend

**Deliverables**:
- ✅ Frontend: `https://marco-sandbox-frontend.azurestaticapps.net`
- ✅ Backend: `https://marco-sandbox-backend.azurewebsites.net/api/*`
- ✅ Frontend and backend deployable independently
- ✅ No more frontend build blocking backend deploys

**Frontend Changes**:
```typescript
// vite.config.ts
export default defineConfig({
  build: {
    outDir: "dist",  // Changed from "../backend/static"
  },
  define: {
    'import.meta.env.VITE_API_URL': JSON.stringify(
      process.env.VITE_API_URL || 'http://localhost:5000'
    )
  }
})

// src/api/api.ts
const API_BASE_URL = import.meta.env.VITE_API_URL;

export async function chatApi(options: ChatRequest): Promise<Response> {
    return await fetch(`${API_BASE_URL}/api/chat`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${await getAuthToken()}`
        },
        body: JSON.stringify(options)
    });
}
```

**Backend Changes**:
```python
# app.py - Remove line 2337
# app.mount("/", StaticFiles(directory="static"), name="static")

# Add CORS
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://marco-sandbox-frontend.azurestaticapps.net",
        "http://localhost:3000"  # Local dev
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Effort**: 3-4 days

---

### Phase 3: Create Test Bench Service (Weeks 3-4)

**Goal**: New microservice for golden question testing and A/B experiments

**Tasks**:
1. Create `app/testbench` directory structure
2. Implement golden question CRUD APIs
3. Implement test run execution with approach comparison
4. Add statistical analysis (t-tests, confidence intervals)
5. Implement evidence collection
6. Create CosmosDB containers for test results
7. Deploy to Azure App Service

**Directory Structure**:
```
app/testbench/
├── api_testbench.py           # Main FastAPI app
├── models.py                  # Pydantic models
├── ab_testing.py              # A/B test execution
├── statistical_analysis.py    # T-tests, confidence
├── evidence_collector.py      # Artifact collection
├── progressive_rollout.py     # Canary deployments
├── requirements.txt
└── Dockerfile
```

**API Endpoints**:
```python
# api_testbench.py
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict
import uuid

app = FastAPI(title="EVA RAG Test Bench", version="1.0.0")

@app.post("/api/testbench/golden-questions")
async def create_golden_question(question: GoldenQuestion):
    """UAT developers submit golden questions"""
    # Store in CosmosDB
    pass

@app.post("/api/testbench/test-runs")
async def create_test_run(suite: str, approach: str, overrides: Dict):
    """Execute test run for suite of golden questions"""
    # Execute tests, collect results
    pass

@app.get("/api/testbench/test-runs/{run_id}")
async def get_test_run(run_id: str):
    """Get test run results with statistical analysis"""
    pass

@app.post("/api/testbench/ab-test")
async def execute_ab_test(experiment: ABTestConfig):
    """Run A/B test comparing two RAG approaches"""
    pass

@app.get("/api/testbench/compare/{run1}/{run2}")
async def compare_test_runs(run1: str, run2: str):
    """Compare two test runs side-by-side"""
    pass
```

**Deliverables**:
- ✅ Test Bench deployed: `https://marco-sandbox-testbench.azurewebsites.net`
- ✅ UAT developers can submit golden questions via API
- ✅ Automated test run execution against RAG APIs
- ✅ Statistical comparison of approaches with confidence intervals
- ✅ Evidence artifacts stored in Blob Storage
- ✅ Test results stored in CosmosDB

**Effort**: 1.5-2 weeks

---

### Phase 4: Add API Management Gateway (Week 5)

**Goal**: Enterprise-grade API gateway with routing, auth, and monitoring

**Tasks**:
1. Create Azure APIM instance
2. Configure routing policies
3. Set up rate limiting
4. Configure authentication passthrough
5. Add AI governance policies
6. Configure Application Insights

**Routing Configuration**:
```xml
<!-- APIM Policy -->
<policies>
    <inbound>
        <!-- Authentication -->
        <validate-jwt header-name="Authorization">
            <openid-config url="https://login.microsoftonline.com/{tenant}/.well-known/openid-configuration" />
        </validate-jwt>
        
        <!-- Rate limiting -->
        <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
        
        <!-- Routing logic -->
        <choose>
            <when condition="@(context.Request.Url.Path.StartsWith("/api/testbench"))">
                <set-backend-service base-url="https://marco-sandbox-testbench.azurewebsites.net" />
            </when>
            <when condition="@(context.Request.Url.Path.StartsWith("/api/rag"))">
                <set-backend-service base-url="https://marco-sandbox-backend.azurewebsites.net" />
            </when>
            <otherwise>
                <return-response>
                    <set-status code="404" />
                </return-response>
            </otherwise>
        </choose>
    </inbound>
    
    <outbound>
        <!-- Remove backend headers -->
        <set-header name="X-Powered-By" exists-action="delete" />
    </outbound>
</policies>
```

**Architecture After Phase 4**:
```
Users → APIM (api.eva.service.gc.ca) → {
    /api/rag/* → RAG Backend
    /api/testbench/* → Test Bench
    / → Static Web App (Frontend)
}
```

**Deliverables**:
- ✅ Single entry point: `https://api.eva.service.gc.ca`
- ✅ Automatic routing to appropriate backend
- ✅ Rate limiting per client
- ✅ Unified authentication
- ✅ Centralized monitoring in Application Insights

**Effort**: 1 week

---

### Phase 5: Netflix-Style Features (Weeks 6+)

**Goal**: Advanced A/B testing and progressive rollout capabilities

**Tasks**:
1. Implement automated A/B test analysis
2. Build progressive rollout automation
3. Create real-time experiment dashboard
4. Add automatic rollback on regression
5. Implement smoke test suite for CI/CD gates

**Deliverables**:
- ✅ Automated A/B testing with statistical analysis
- ✅ Progressive rollout: 1% → 5% → 25% → 50% → 100%
- ✅ Automatic rollback if quality drops > 5%
- ✅ Real-time dashboard showing experiment results
- ✅ CI/CD quality gates preventing bad deployments

**Effort**: 2-3 weeks

---

## Code Examples

### Complete Test Bench API Implementation

```python
# app/testbench/api_testbench.py

from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Optional
import uuid
from datetime import datetime
import asyncio

app = FastAPI(title="EVA RAG Test Bench API", version="1.0.0")

# Pydantic Models
class GoldenQuestion(BaseModel):
    question: str
    expected_answer: str
    expected_citations: List[str]
    test_suite: str
    metadata: Dict = {}

class TestRunConfig(BaseModel):
    test_suite: str
    rag_approach: str
    overrides: Dict
    parallel: bool = False

class ABTestConfig(BaseModel):
    experiment_id: str
    variants: Dict[str, Dict]  # variant_name -> config
    sample_size: int
    primary_metric: str

# Endpoints
@app.post("/api/testbench/golden-questions")
async def create_golden_question(question: GoldenQuestion):
    """UAT developers submit golden questions"""
    
    question_id = str(uuid.uuid4())
    
    # Store in CosmosDB
    await cosmos_client.upsert_item("golden-questions", {
        "id": question_id,
        "question": question.question,
        "expected_answer": question.expected_answer,
        "expected_citations": question.expected_citations,
        "test_suite": question.test_suite,
        "created_at": datetime.utcnow().isoformat(),
        "metadata": question.metadata
    })
    
    return {
        "id": question_id,
        "status": "created",
        "message": "Golden question added to suite"
    }

@app.post("/api/testbench/test-runs")
async def create_test_run(
    config: TestRunConfig,
    background_tasks: BackgroundTasks
):
    """Execute test run for suite of golden questions"""
    
    run_id = str(uuid.uuid4())
    
    # Fetch golden questions for suite
    questions = await cosmos_client.query_items(
        "golden-questions",
        f"SELECT * FROM c WHERE c.test_suite = '{config.test_suite}'"
    )
    
    if not questions:
        raise HTTPException(404, f"No questions found in suite: {config.test_suite}")
    
    # Create test run record
    test_run = {
        "id": run_id,
        "test_suite": config.test_suite,
        "rag_approach": config.rag_approach,
        "overrides": config.overrides,
        "status": "pending",
        "created_at": datetime.utcnow().isoformat(),
        "questions": [q["id"] for q in questions],
        "results": []
    }
    
    await cosmos_client.upsert_item("test-runs", test_run)
    
    # Execute in background
    background_tasks.add_task(
        execute_test_run,
        run_id,
        questions,
        config.rag_approach,
        config.overrides
    )
    
    return {
        "run_id": run_id,
        "status": "pending",
        "questions_count": len(questions),
        "message": "Test run started"
    }

async def execute_test_run(
    run_id: str,
    questions: List[Dict],
    approach: str,
    overrides: Dict
):
    """Execute test run by calling RAG API for each question"""
    
    results = []
    
    for q in questions:
        try:
            # Call RAG Core API
            rag_response = await rag_client.chat({
                "history": [{"role": "user", "content": q["question"]}],
                "approach": approach,
                "overrides": overrides
            })
            
            # Calculate quality score
            quality_score = calculate_similarity(
                rag_response["answer"],
                q["expected_answer"]
            )
            
            # Check citation accuracy
            citation_match = compare_citations(
                rag_response.get("citations", []),
                q["expected_citations"]
            )
            
            result = {
                "question_id": q["id"],
                "question": q["question"],
                "actual_answer": rag_response["answer"],
                "expected_answer": q["expected_answer"],
                "quality_score": quality_score,
                "actual_citations": rag_response.get("citations", []),
                "expected_citations": q["expected_citations"],
                "citation_accuracy": citation_match,
                "latency_ms": rag_response.get("latency_ms", 0),
                "cost": estimate_cost(rag_response),
                "timestamp": datetime.utcnow().isoformat(),
                "status": "passed" if quality_score >= 0.8 else "failed"
            }
            
            results.append(result)
            
        except Exception as e:
            results.append({
                "question_id": q["id"],
                "error": str(e),
                "status": "error"
            })
    
    # Calculate summary statistics
    passed = sum(1 for r in results if r.get("status") == "passed")
    failed = sum(1 for r in results if r.get("status") == "failed")
    errors = sum(1 for r in results if r.get("status") == "error")
    
    valid_scores = [r["quality_score"] for r in results if "quality_score" in r]
    avg_score = sum(valid_scores) / len(valid_scores) if valid_scores else 0
    
    valid_latencies = [r["latency_ms"] for r in results if "latency_ms" in r]
    avg_latency = sum(valid_latencies) / len(valid_latencies) if valid_latencies else 0
    
    # Update test run
    await cosmos_client.update_item("test-runs", run_id, {
        "status": "completed",
        "results": results,
        "completed_at": datetime.utcnow().isoformat(),
        "summary": {
            "total": len(questions),
            "passed": passed,
            "failed": failed,
            "errors": errors,
            "avg_quality_score": avg_score,
            "avg_latency_ms": avg_latency,
            "pass_rate": passed / len(questions) if questions else 0
        }
    })

@app.get("/api/testbench/test-runs/{run_id}")
async def get_test_run(run_id: str):
    """Get test run results"""
    
    test_run = await cosmos_client.get_item("test-runs", run_id)
    
    if not test_run:
        raise HTTPException(404, f"Test run not found: {run_id}")
    
    return test_run

@app.post("/api/testbench/ab-test")
async def execute_ab_test(config: ABTestConfig):
    """Run A/B test comparing multiple RAG variants"""
    
    experiment_id = config.experiment_id
    
    # Create experiment
    experiment = {
        "id": experiment_id,
        "variants": config.variants,
        "sample_size": config.sample_size,
        "primary_metric": config.primary_metric,
        "status": "running",
        "started_at": datetime.utcnow().isoformat()
    }
    
    await cosmos_client.upsert_item("experiments", experiment)
    
    # Execute variants in parallel
    tasks = []
    for variant_name, variant_config in config.variants.items():
        task = execute_variant(
            experiment_id,
            variant_name,
            variant_config,
            config.sample_size
        )
        tasks.append(task)
    
    await asyncio.gather(*tasks)
    
    # Analyze results
    analysis = await analyze_experiment(experiment_id)
    
    return analysis

async def analyze_experiment(experiment_id: str):
    """Statistical analysis of A/B test results"""
    
    experiment = await cosmos_client.get_item("experiments", experiment_id)
    results = await cosmos_client.query_items(
        "experiment-results",
        f"SELECT * FROM c WHERE c.experiment_id = '{experiment_id}'"
    )
    
    # Group by variant
    from scipy import stats
    import numpy as np
    
    variants_data = {}
    for variant_name in experiment["variants"].keys():
        variant_results = [r for r in results if r["variant"] == variant_name]
        scores = [r["quality_score"] for r in variant_results]
        
        variants_data[variant_name] = {
            "mean": np.mean(scores),
            "std": np.std(scores),
            "median": np.median(scores),
            "p95": np.percentile(scores, 95),
            "sample_size": len(scores),
            "scores": scores
        }
    
    # T-test between control and treatment
    control_scores = variants_data["control"]["scores"]
    treatment_scores = variants_data["treatment"]["scores"]
    
    t_stat, p_value = stats.ttest_ind(control_scores, treatment_scores)
    
    control_mean = variants_data["control"]["mean"]
    treatment_mean = variants_data["treatment"]["mean"]
    
    # Decision
    is_significant = p_value < 0.05
    is_improvement = treatment_mean > control_mean
    
    if is_significant and is_improvement:
        improvement_pct = ((treatment_mean - control_mean) / control_mean) * 100
        decision = {
            "winner": "treatment",
            "confidence": f"{(1 - p_value) * 100:.1f}%",
            "improvement": f"+{improvement_pct:.1f}%",
            "recommendation": "DEPLOY_TO_100_PERCENT"
        }
    else:
        decision = {
            "winner": "control",
            "recommendation": "KEEP_CURRENT_VERSION"
        }
    
    return {
        "experiment_id": experiment_id,
        "variants": variants_data,
        "statistical_analysis": {
            "t_statistic": t_stat,
            "p_value": p_value,
            "significant": is_significant
        },
        "decision": decision
    }

@app.get("/api/testbench/compare/{run1}/{run2}")
async def compare_test_runs(run1: str, run2: str):
    """Compare two test runs side-by-side"""
    
    run1_data = await cosmos_client.get_item("test-runs", run1)
    run2_data = await cosmos_client.get_item("test-runs", run2)
    
    if not run1_data or not run2_data:
        raise HTTPException(404, "One or both test runs not found")
    
    return {
        "run1": {
            "id": run1,
            "approach": run1_data["rag_approach"],
            "summary": run1_data["summary"]
        },
        "run2": {
            "id": run2,
            "approach": run2_data["rag_approach"],
            "summary": run2_data["summary"]
        },
        "comparison": {
            "quality_delta": run2_data["summary"]["avg_quality_score"] - run1_data["summary"]["avg_quality_score"],
            "latency_delta": run2_data["summary"]["avg_latency_ms"] - run1_data["summary"]["avg_latency_ms"],
            "winner_by_quality": run2 if run2_data["summary"]["avg_quality_score"] > run1_data["summary"]["avg_quality_score"] else run1
        }
    }

# Health check
@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "service": "test-bench",
        "version": "1.0.0"
    }
```

---

## Summary

This architecture transforms the monolithic EVA-JP application into a modern microservices architecture with:

1. **Independent Deployment**: Frontend, RAG APIs, and Test Bench deploy independently
2. **Netflix-Style Testing**: Statistical A/B testing with progressive rollout
3. **Quality Gates**: Automated smoke tests prevent bad deployments
4. **Enterprise Scale**: Handles 1000+ users, multiple RAG experiments simultaneously
5. **Complete Audit Trail**: Evidence collection for compliance
6. **Developer-Friendly**: Simple SDK for UAT developers

The phased approach minimizes risk while maximizing value:
- Week 1: Fix current issue
- Week 2: Separate frontend
- Weeks 3-4: Build test bench
- Week 5: Add APIM gateway
- Weeks 6+: Netflix-style features

**Result**: World-class RAG testing infrastructure enabling continuous quality improvement with scientific rigor.

---

**Next Steps**: 
1. Review this document with stakeholders
2. Get approval for phased approach
3. Begin Phase 1 implementation
4. Set up monitoring and alerting infrastructure
5. Train UAT developers on test bench SDK

---

**References**:
- EVA Brain Architecture: `EVA-ARCHITECTURE-SCAFFOLD-PLAN.md`
- EVA Face Strategy: `EVA-FACE-STRATEGY.md`
- Netflix A/B Testing: Industry best practices
- Source System: `I:\EVA-Jurisprudence-SecMode-Info-Assistant-v1.2`
