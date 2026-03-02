# EVA Brain - Revised Action Plan

**Date**: February 3, 2026  
**Status**: Pre-Implementation - Awaiting Phase 0.5 Validation  
**Timeline**: 8-9 days (revised from 5 days)

---

## Quick Reference: What Changed

| Aspect | Original Plan | Revised Plan | Reason |
|--------|---------------|--------------|---------|
| **Timeline** | 5 days | 8-9 days | Added buffer for blockers |
| **First Step** | Start Spark development | Validate Spark capabilities | Eliminate uncertainty |
| **Success Definition** | Working EVA Chat clone | Spark capability assessment | Manage expectations |
| **Rollback Plan** | None | 3 contingencies defined | Risk management |
| **Success Metrics** | Subjective | Quantified (< 30s, 8/10, etc.) | Clear exit criteria |

---

## Phase 0.5: Spark Validation Sprint ⭐ NEW PHASE

**Duration**: Day 1 (6-8 hours)  
**Owner**: 1 senior developer (not full team)  
**Objective**: Validate Spark can generate EVA Brain requirements before team commitment

### Validation Tests

#### Test 1: Basic Code Generation (1 hour)
```
Prompt: "Build a React chat interface with TypeScript, message input, send button"

Success Criteria:
✅ TypeScript interfaces generated
✅ No @spark/* dependencies in package.json
✅ Export produces standalone project
✅ npm install && npm run build succeeds

Exit Criteria: If fails → ABORT Spark path, use existing EVA-JP frontend
```

#### Test 2: SSE Streaming (2 hours)
```
Prompt: "Add Server-Sent Events streaming from /api/chat endpoint"

Success Criteria:
✅ Uses EventSource API or fetch with ReadableStream
✅ Displays streaming text token-by-token
✅ Works with mock SSE endpoint

Exit Criteria: If fails → NO-GO for Spark streaming features
```

#### Test 3: API Integration (2 hours)
```
Prompt: "Call POST /chat with body {messages: [...], session_state: {...}}"

Success Criteria:
✅ Generates fetch() with proper headers, body, error handling
✅ TypeScript types match EVA-JP API contract
✅ Integration test passes with localhost:5000 backend

Exit Criteria: If fails → Spark cannot integrate with EVA-JP backend
```

#### Test 4: Code Quality (1 hour)
```
Assessment:
✅ ESLint passes (or minimal warnings)
✅ TypeScript compilation: 0 errors
✅ Component structure follows React best practices
✅ Production-readiness score: 7/10 or higher

Exit Criteria: If < 7/10 → Spark code quality insufficient for demo
```

### Go/No-Go Decision

**GO Criteria** (ALL must pass):
- ✅ All 4 tests pass
- ✅ Code quality ≥ 7/10
- ✅ Zero Spark-specific dependencies
- ✅ Integration with localhost:5000 works

**NO-GO Triggers** (ANY fails):
- ❌ Cannot generate TypeScript
- ❌ SSE streaming broken
- ❌ API integration requires manual refactor
- ❌ Code quality < 7/10

**Deliverable**: `SPARK-VALIDATION-REPORT.md` in `runs/validation/`

---

## Phase 1: Spark Development (Days 2-5)

**Prerequisites**: Phase 0.5 GO decision approved

### Day 2: Basic Chat Interface
- [ ] Create new Spark app
- [ ] Provide context: PRD + API contracts
- [ ] Prompt: "Build chat UI with message input, streaming responses"
- [ ] Test integration with localhost:5000 backend
- [ ] Capture screenshot evidence

**Exit Criteria**: User can send message → receive streaming response

### Day 3: Polish & Error Handling (Optional)
- [ ] Add markdown rendering
- [ ] Implement loading states
- [ ] Display error messages
- [ ] Clear chat button

**Exit Criteria**: UI handles errors gracefully

**Contingency**: Skip if behind schedule, move to Day 4

### Day 4-5: RAG Implementation
- [ ] Add "RAG" mode toggle
- [ ] Implement selectedFolders parameter
- [ ] Display citations (data_points)
- [ ] Test with PSHCP query

**Exit Criteria**: RAG query returns answer with ≥ 1 citation

**Contingency**: Use basic RAG (no folder selection) if time constrained

---

## Phase 2: Export & Integration (Days 6-7)

### Day 6: Export Validation
- [ ] Export Spark project to local directory
- [ ] Inspect package.json for Spark dependencies
- [ ] Run: `npm install && npm run build`
- [ ] Validate TypeScript compilation (0 errors)
- [ ] Remove Spark dependencies if present

**Exit Criteria**: Build succeeds without Spark login

**Contingency**: If export fails, use Spark web preview for demo only (no deployment)

### Day 7: Merge to EVA Brain
- [ ] Create feature branch: `spark-poc-chat-ui`
- [ ] Copy exported code to app/ folder
- [ ] Update package.json
- [ ] Test locally (frontend + backend integration)
- [ ] Commit and push to GitHub

**Exit Criteria**: End-to-end test passes (Chat + RAG queries work)

**Contingency**: If integration fails, run Spark app standalone (skip merge)

---

## Phase 3: Demo Preparation (Day 8)

### Morning: Environment Setup & Dry Run
- [ ] Start backend on localhost:5000
- [ ] Verify frontend on localhost:5173
- [ ] Test 10-developer access (or shared URL)
- [ ] Walkthrough demo script (5 scenarios)
- [ ] Record backup video (in case live demo fails)

### Afternoon: Documentation
- [ ] Write demo script with timings
- [ ] Create survey questions (Google Forms)
- [ ] Prepare slides explaining Spark workflow
- [ ] Review contingency plans

**Exit Criteria**: Dry run successful, backup video captured

---

## Phase 4: Demo & Debrief (Day 9)

### Morning: Live Demo (1 hour)
**Scenario 1**: Basic Chat (30 seconds)
- Question: "What is Employment Insurance?"
- Expected: Streaming response with markdown

**Scenario 2**: RAG Query (90 seconds)
- Question: "PSHCP eligibility rules"
- Expected: Answer with citations

**Scenario 3**: Citations Display (60 seconds)
- Action: Click citation link
- Expected: Source document reference

**Scenario 4**: Error Handling (30 seconds)
- Action: Stop backend temporarily
- Expected: Error message displayed

**Scenario 5**: Mode Switch (30 seconds)
- Action: Toggle Chat ↔ RAG modes
- Expected: UI updates correctly

### Afternoon: Debrief & Survey (1 hour)
- [ ] Collect survey responses (10 developers)
- [ ] Review lessons learned
- [ ] Document Spark recommendations
- [ ] Write POST-DEMO-REPORT.md

---

## Rollback Plans (Contingencies)

### If Phase 0.5 Fails (Spark Validation)
**Trigger**: Any validation test fails  
**Action**: Use existing EVA-JP frontend, rename as "EVA Brain Demo"  
**Demo Message**: "We validated Spark but found it doesn't meet ESDC standards for [reason]. Here's why we chose traditional React development instead."  
**Value**: Still demonstrates API integration, RAG patterns, and tool evaluation methodology

### If Export Fails (Day 6)
**Trigger**: Export produces non-standalone code  
**Action**: Use Spark web preview URL for demo  
**Trade-off**: No deployment to App Service, but functionality demonstrated  
**Demo Message**: "Spark generates working apps but export process needs refinement"

### If Integration Fails (Day 7)
**Trigger**: Exported code won't run with EVA-JP backend  
**Action**: Run Spark app standalone, skip merge to eva-brain repo  
**Trade-off**: No reference implementation in GitHub  
**Demo Message**: "Spark UI works but API integration requires manual refactoring"

### If Live Demo Fails (Day 9)
**Trigger**: Environment issues, network failures  
**Action**: Play backup video recording  
**Preparation**: Record successful demo on Day 8  
**Demo Message**: "Here's a recording of the working demo to show functionality"

---

## Success Metrics (Quantified)

### Minimum Viable Success (ALL required)
- ✅ Spark validation complete (report written)
- ✅ Basic chat UI functional (send/receive works)
- ✅ RAG query returns citations (PSHCP test passes)
- ✅ Code exported and built successfully (no errors)
- ✅ 10 developers see demo (live or video)

### Stretch Goals (NICE to have)
- ⭐ Full chat + RAG feature parity
- ⭐ Deployed to Azure App Service
- ⭐ Merged to eva-brain main branch
- ⭐ Survey score ≥ 8.0/10
- ⭐ Developers can list 3+ Spark benefits

### Demo Day Measurements
- **Access Success**: 10/10 developers access UI (100%)
- **Time to First Chat**: Median < 30 seconds (stopwatch)
- **Time to RAG Query**: Median < 2 minutes
- **Confidence Score**: Average ≥ 8.0/10 (survey)
- **Spark Value Understanding**: ≥ 7/10 can describe use cases

---

## Daily Checklist

### Day 1: Validation
- [ ] Morning: Assign developer, brief on validation tests
- [ ] Afternoon: Execute tests, write report
- [ ] End of day: Go/no-go decision made

### Day 2: Chat UI
- [ ] Morning: Create Spark app, provide context
- [ ] Afternoon: Test integration, capture evidence
- [ ] End of day: Basic chat working or escalate

### Day 3: Polish (Optional)
- [ ] Morning: Add markdown, loading states
- [ ] Afternoon: Error handling, clear button
- [ ] End of day: Decision to continue or skip to Day 4

### Day 4-5: RAG
- [ ] Day 4 morning: Add RAG mode toggle
- [ ] Day 4 afternoon: Implement selectedFolders
- [ ] Day 5 morning: Display citations
- [ ] Day 5 afternoon: Test PSHCP query

### Day 6: Export
- [ ] Morning: Export Spark project
- [ ] Afternoon: Validate build, remove dependencies
- [ ] End of day: Standalone build ready or contingency activated

### Day 7: Integration
- [ ] Morning: Merge to eva-brain repo
- [ ] Afternoon: Test end-to-end, fix issues
- [ ] End of day: Integration complete or standalone fallback

### Day 8: Demo Prep
- [ ] Morning: Dry run with 10 developers
- [ ] Afternoon: Write script, record backup video
- [ ] End of day: Demo ready checklist complete

### Day 9: Demo Day
- [ ] Morning: Live demo (1 hour)
- [ ] Afternoon: Survey, debrief, document lessons

---

## Communication Plan

### Stakeholder Updates (End of Each Phase)

**After Day 1 (Validation)**:
```
Subject: EVA Brain Phase 0.5 Complete - [GO/NO-GO]

Result: [GO/NO-GO decision]
Findings: [4 test results summary]
Next Steps: [Phase 1 start OR pivot to existing frontend]
Risk Assessment: [Updated based on validation]
```

**After Day 5 (Spark Development)**:
```
Subject: EVA Brain Phase 1 Complete - Spark UI Ready

Status: Basic chat + RAG implemented
Evidence: [Screenshots in evidence/ folder]
Code Quality: [Assessment score]
Next Steps: Export and integration (Phase 2)
```

**After Day 7 (Integration)**:
```
Subject: EVA Brain Phase 2 Complete - Code Merged

Status: Exported code integrated with EVA-JP backend
Build Status: [Success/Issues]
Demo Readiness: [Percentage complete]
Next Steps: Demo preparation (Phase 3)
```

**After Day 9 (Demo)**:
```
Subject: EVA Brain Demo Complete - Survey Results

Attendance: [X/10 developers participated]
Survey Score: [Average confidence rating]
Key Findings: [Top 3 lessons learned]
Recommendation: [Spark usage guidelines]
Next Steps: [Documentation finalization]
```

---

## Documentation Deliverables

### Required (Before Demo)
- [ ] SPARK-VALIDATION-REPORT.md (Day 1)
- [ ] SPARK-USAGE-GUIDELINES.md (Day 7)
- [ ] DEMO-SCRIPT.md (Day 8)
- [ ] BACKUP-VIDEO.mp4 (Day 8)

### Required (After Demo)
- [ ] POST-DEMO-REPORT.md (Day 9)
- [ ] LESSONS-LEARNED.md (Day 9)
- [ ] SURVEY-RESULTS.md (Day 9)

### Optional (If Time Permits)
- [ ] SPARK-CODE-QUALITY-ANALYSIS.md
- [ ] EVA-JP-INTEGRATION-PATTERNS.md
- [ ] FUTURE-RECOMMENDATIONS.md

---

## Risk Register (Live Tracking)

| Risk ID | Description | Probability | Impact | Status | Mitigation |
|---------|-------------|-------------|--------|--------|------------|
| R1 | Spark validation fails | MEDIUM | HIGH | OPEN | Phase 0.5 validation sprint |
| R2 | Timeline overrun | HIGH | HIGH | OPEN | 8-day schedule with buffer |
| R3 | Export includes dependencies | MEDIUM | MEDIUM | OPEN | De-sparkify script prepared |
| R4 | SSE streaming broken | MEDIUM | HIGH | OPEN | Test in Phase 0.5 |
| R5 | 10-developer access fails | LOW | MEDIUM | OPEN | Dry run on Day 8 |
| R6 | Live demo environment issues | LOW | HIGH | OPEN | Backup video recording |

**Update After Each Phase**: Move risks from OPEN → CLOSED or ESCALATED

---

## Success Definition (Final)

This PoC is **successful** if:

1. ✅ **Validation Complete**: Spark capabilities documented (positive or negative findings)
2. ✅ **Demonstration Delivered**: 10 developers see working chat UI (live or video)
3. ✅ **Knowledge Transfer**: Developers understand when to use Spark vs. traditional development
4. ✅ **Documentation Created**: Lessons learned and recommendations captured
5. ✅ **Reference Implementation**: Code exported and available for future projects

**Note**: "Working EVA Chat clone" is NOT required for success. Even if Spark underperforms, documenting its limitations is a valuable outcome.

---

## Approval Signatures

**Before proceeding to implementation, obtain approvals**:

- [ ] **Project Lead**: Reviewed revised timeline and risk mitigations
- [ ] **Development Team**: Understands Phase 0.5 validation requirement
- [ ] **10 Developers**: Briefed on demo expectations (capability assessment)
- [ ] **Architecture**: Approved rollback plans and contingencies

**Signature Line**: _________________________  
**Date**: _________________________

---

**Action Plan Version**: 1.0  
**Last Updated**: February 3, 2026  
**Next Review**: After Phase 0.5 validation (Day 1 EOD)

