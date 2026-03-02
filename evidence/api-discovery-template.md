# EVA Brain API Discovery Summary

**Capture Date**: YYYY-MM-DD HH:MM:SS  
**Captured By**: [Your Name]  
**Session ID**: [Optional]

---

## Environment

- **Site URL**: 
- **Date and Time**: 
- **Browser**: 
- **Network**: ESDC internal / VPN
- **Authentication**: Already logged in

---

## Chat API (Ungrounded)

### Request Details
- **URL**: 
- **Method**: 
- **Request Headers** (redacted):
  ```
  Content-Type: application/json
  Authorization: [REDACTED]
  ```
- **Request Body**:
  ```json
  {
    
  }
  ```

### Response Details
- **Status**: 
- **Response Body** (first 1-2 KB):
  ```json
  {
    
  }
  ```

### Notes
- 

---

## Chat API (Grounded - proj1)

### Request Details
- **URL**: 
- **Method**: 
- **Request Headers** (redacted):
  ```
  Content-Type: application/json
  Authorization: [REDACTED]
  ```
- **Request Body**:
  ```json
  {
    
  }
  ```

### Response Details
- **Status**: 
- **Response Body** (first 1-2 KB):
  ```json
  {
    
  }
  ```

### Notes
- 

---

## Streaming or Polling

### Endpoint Details
- **URL**: 
- **Method**: 
- **Request Parameters**: 
- **Notes**: 

---

## Additional Observations

### Index/Folder Selection
- How is the proj1 index specified in the request?
- Parameter name:
- Parameter value:

### Authentication
- Token type: Bearer / Cookie / Other
- Token location: Header / Query / Body

### Error Handling
- Error response format:
- Status codes observed:

---

## Evidence Files

- HAR file: `har-capture-YYYYMMDD_HHMMSS.har` (DO NOT SHARE EXTERNALLY)
- Screenshots: `screenshots/`
  - `screenshot-01-ui-before.png`
  - `screenshot-02-devtools-network.png`
  - `screenshot-03-request-details.png`

---

## Security Notes

- [X] All authentication tokens redacted
- [X] No external sharing
- [X] Complies with ITS07 (no external API exposure)
- [X] Complies with IOP01 (internal integration only)

---

## Next Steps

- [ ] Review captured endpoints with architecture team
- [ ] Create test harness based on discovered patterns
- [ ] Document integration approach in EVA-BRAIN-END-TO-END-PLAN.md

---

**Related Documentation**:
- I:\eva-foundation\24-eva-brain\COPILOT-DISCOVERY-RUNBOOK.md
- I:\eva-foundation\24-eva-brain\EVA-BRAIN-END-TO-END-PLAN.md
- I:\eva-foundation\09-EVA-Repo-documentation\EVA-TechDesConOps.v02\03_eva_chat_requirements.md
