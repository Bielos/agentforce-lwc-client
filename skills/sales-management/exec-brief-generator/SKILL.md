---
name: exec-brief-generator
description: Produces concise executive business reviews across pipeline, forecast, risks, and required interventions. Use when the user asks for leadership updates, weekly business reviews, QBR prep, manager summaries, or CRO/VP-level status reporting.
---

# Exec Brief Generator

AI Agent Skill

Builds leadership-ready summaries that highlight what changed, what is at risk, and where intervention is needed.

## Goal

Enable fast, decision-grade updates for sales leadership with minimal noise and clear action ownership.

## Steps

1. Define briefing scope
- Confirm audience (manager, VP Sales, CRO, cross-functional leadership).
- Confirm period (weekly, monthly, quarterly) and segment (team, region, product line).

2. Gather core metrics
- Pipeline coverage and movement.
- Forecast by category (Commit, Best Case, Pipeline) and week-over-week delta.
- Win/loss trend, average cycle time, and stage conversion where available.
- Top deal changes (new, advanced, slipped, dropped).

3. Identify material changes
- Surface changes that alter forecast confidence or execution risk.
- Highlight outliers: large upside, large downside, unusual slippage, concentration risk.

4. Isolate top risks
- Rank key risks by potential revenue impact and probability.
- Provide short evidence for each risk (activity gap, missing stakeholders, stage stall, deal dependency).

5. Recommend leadership interventions
- Propose focused actions where leadership help can change outcomes:
  - executive sponsor outreach
  - pricing/terms decision
  - cross-functional unblock (legal/security/services)
  - rep coaching priority

6. Define next review checkpoints
- Assign owners and due dates for intervention follow-through.
- State what will be measured before the next brief.

## Output Format

### Executive Brief
- Audience:
- Period:
- Overall confidence: `High/Medium/Low`

### Headline Metrics
- Pipeline coverage:
- Forecast this period:
- Commit delta vs last review:
- Best case delta vs last review:
- Win rate trend:

### What Changed Since Last Review
- 3-7 bullets with only material business changes.

### Top Risks (Ranked)
Risk | Revenue Impact | Likelihood | Evidence | Owner

### Required Leadership Interventions
Intervention | Why now | Owner | Due date | Expected outcome

### Deal Spotlight
- **Upside candidate(s):** `<deal + reason + required action>`
- **Downside risk(s):** `<deal + reason + required action>`

### Next Checkpoint Commitments
- Commitment | Owner | Due date | Success signal

## Notes

- Keep language executive-level: short, specific, and evidence-backed.
- Prioritize decisions and interventions over operational detail.
- If data quality is weak, include a brief "Data confidence" note and call out missing fields.
