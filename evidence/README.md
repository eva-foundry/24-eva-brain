# EVA Brain API Discovery Evidence

## Purpose

This directory contains evidence from manual API discovery sessions for EVA Brain integration work.

## Directory Structure

```
evidence/
├── README.md                              # This file
├── .gitignore                             # Security controls
├── api-discovery-template.md              # Template for new discoveries
├── api-discovery-YYYYMMDD_HHMMSS.md      # Actual discovery sessions (gitignored)
├── har-capture-YYYYMMDD_HHMMSS.har       # HAR files (gitignored)
└── screenshots/                           # UI and network captures (gitignored)
```

## Usage

1. **Before Discovery**: Copy `api-discovery-template.md` to a new timestamped file
2. **During Discovery**: Follow [COPILOT-DISCOVERY-RUNBOOK.md](../COPILOT-DISCOVERY-RUNBOOK.md)
3. **After Discovery**: Save HAR files and screenshots here
4. **Security**: All actual discovery files are gitignored automatically

## Security Controls

- ✅ `.gitignore` prevents committing sensitive data
- ✅ All actual discoveries use naming pattern: `*-actual-*.md` or `*-session-*.md`
- ✅ HAR files are blocked from version control
- ✅ Screenshots are blocked from version control
- ✅ Only templates and sanitized examples can be committed

## Compliance

- **ITS07**: No external API exposure
- **IOP01**: Internal integration only
- **Evidence Retention**: Per ESDC data classification policies

## Related Documentation

- [COPILOT-DISCOVERY-RUNBOOK.md](../COPILOT-DISCOVERY-RUNBOOK.md) - Discovery procedure
- [EVA-BRAIN-END-TO-END-PLAN.md](../EVA-BRAIN-END-TO-END-PLAN.md) - Integration plan
- [03_eva_chat_requirements.md](../../09-EVA-Repo-documentation/EVA-TechDesConOps.v02/03_eva_chat_requirements.md) - Requirements

---

**Last Updated**: 2026-02-02
