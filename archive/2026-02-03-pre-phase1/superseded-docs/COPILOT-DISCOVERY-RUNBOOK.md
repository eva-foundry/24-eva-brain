---
document_type: copilot_runbook
phase: phase-0
audience: [engineering, architecture, security]
traceability:
  - I:\eva-foundation\24-eva-brain\EVA-BRAIN-END-TO-END-PLAN.md
  - I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md
---

# Copilot Discovery Runbook - EVA Brain API Surface (Browser-Based)

## Scope

### In scope
- Use a logged-in browser session to discover IA backend API endpoints for EVA Brain integration.
- Capture request and response shapes for chat and grounded chat.
- Produce a local, plaintext summary that can be used to build a test harness.

### Out of scope
- Any public API exposure or external sharing of captured endpoints.
- Changes to production settings or data.
- Automated crawling or scanning outside the app workflows.

### Primary audience
- Copilot agent or developer performing manual API discovery.

## Preconditions

- You are already logged in to both sites in the browser profile you will use.
- Use the same network and device you normally use to access these apps.
- Do not sign out or switch accounts during capture.

## Target Sites

- https://domain.eva.service.gc.ca/
- https://chat.eva-ave.prv/

## Safety and Governance Notes

- Do not expose captured endpoints or tokens outside internal documentation.
- Do not share cookies or access tokens in responses.
- Any external API exposure conflicts with ITS07 and IOP01 requirements.

## Steps - Manual Discovery

### 1) Open Developer Tools

- Open Chrome or Edge.
- Open the target site.
- Press F12 to open DevTools.
- Go to the Network tab.
- Enable Preserve log.
- Clear the network list.

### 2) Capture a Chat Session (Ungrounded)

- In the UI, select a mode that is NOT grounded in data (if available).
- Enter a short question (for example: "What is the purpose of this assistant?").
- Submit the question.
- Wait for the answer to finish.

### 3) Capture a Chat Session (Grounded - proj1 index)

- In the UI, select the index or folder that maps to proj1.
- Enter a short question that should use the index.
- Submit the question.
- Wait for the answer to finish.

### 4) Identify the API Calls

- In DevTools Network, filter by XHR or Fetch.
- Find the request that carries the question payload.
- Record the following fields for the chat request:
  - Full URL
  - Method
  - Request headers (redact auth tokens)
  - Request payload (body)
  - Response status
  - Response body (first 1-2 KB only)

### 5) Identify Streaming or Polling Calls

- If the response streams, locate the streaming endpoint.
- Record its URL, method, and any required parameters.

### 6) Export a HAR (Optional)

- In Network tab, right click and choose "Save all as HAR with content".
- Save locally and do not share the file externally.

## Output - Required Deliverable

Create a plaintext summary file with the following sections:

```
# EVA Brain API Discovery Summary

## Environment
- Site URL:
- Date and time:
- Browser:

## Chat API (Ungrounded)
- URL:
- Method:
- Request headers (redact tokens):
- Request body:
- Response status:
- Response body (first 1-2 KB):

## Chat API (Grounded - proj1)
- URL:
- Method:
- Request headers (redact tokens):
- Request body:
- Response status:
- Response body (first 1-2 KB):

## Streaming or Polling
- URL:
- Method:
- Request parameters:
- Notes:
```

## Acceptance Criteria

- Both ungrounded and grounded requests are captured.
- The request payloads include any index or folder selectors.
- No auth tokens are stored in the summary file.

## Implementation Evidence

- Requirement ITS07 (I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md#L137-L138) prohibits external API exposure.
- Requirement IOP01 (I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md#L54-L56) restricts integration with internal applications.

## Validation Commands

```powershell
# Use these only after you have the base URL and endpoint path
# Replace <BASE_URL> and <PATH> with captured values
curl <BASE_URL><PATH>
```

## Related Documentation

- I:\eva-foundation\24-eva-brain\EVA-BRAIN-END-TO-END-PLAN.md
- I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md
