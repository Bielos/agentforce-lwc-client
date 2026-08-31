---
name: renewal-risk-detector
description: Detects renewal and churn risk by analyzing account health, stakeholder changes, service friction, and commercial timing signals. Use when the user asks for renewal risk reviews, churn prevention plans, or save strategy recommendations.
---

# Renewal Risk Detector

AI Agent Skill

Assesses upcoming renewals, surfaces churn risk drivers, and recommends targeted save actions.

## Goal

Help teams prevent avoidable churn by identifying high-risk renewals early and assigning practical interventions.

## Steps

1. Define renewal cohort
- Confirm renewal window (for example: next 30/60/90/120 days).
- Identify scope (single CSM/AE book, region, product, strategic accounts).

2. Gather account and contract signals
- Renewal date, contract value, product mix, and term details.
- Opportunity/renewal stage, owner, and next step.
- Open/critical support cases and escalation history.
- Activity recency across buyer stakeholders.
- Sponsor or champion changes where available.

3. Evaluate risk dimensions (0-100 each)
- Relationship health: engagement quality and stakeholder continuity.
- Value realization: evidence of adoption/ROI signals if available.
- Service friction: severity and recency of support issues.
- Commercial readiness: timeline, procurement readiness, negotiation progress.
- Competitive vulnerability: signs of displacement risk.

4. Compute renewal risk score
- Weighted model suggestion:
  - Relationship health: 25%
  - Value realization: 25%
  - Service friction: 20%
  - Commercial readiness: 20%
  - Competitive vulnerability: 10%
- Convert to risk band:
  - 0-39: Low risk
  - 40-69: Medium risk
  - 70-100: High risk

5. Identify primary churn drivers
- List top 2-4 risk causes with direct evidence.
- Distinguish controllable vs structural risks.

6. Build save plan
- Recommend 3-6 actions with owner and due date.
- Include both customer-facing and internal actions.
- Ensure at least one near-term action is executable within 48 hours.

7. Set monitoring cadence
- Define weekly review checkpoints until renewal date.
- Track whether risk band is improving, flat, or worsening.

## Output Format

### Renewal Risk Overview
Account | Renewal Date | Contract Value | Risk Score | Risk Band | Primary Driver | Immediate Action

### Account Risk Drill-Down
- Account:
- Risk score / band:
- Top drivers:
  1) `<driver>` - evidence: `<signal>`
  2) `<driver>` - evidence: `<signal>`
- Save plan:
  1) `<action>` (Owner: `<name>`, Due: `<date>`)
  2) `<action>` (Owner: `<name>`, Due: `<date>`)
  3) `<action>` (Owner: `<name>`, Due: `<date>`)
- Escalation need: `<yes/no + to whom>`

### Portfolio Recommendations
- High-risk renewals needing exec attention:
- Medium-risk renewals to stabilize this week:
- Low-risk renewals to maintain:

## Notes

- Prioritize upcoming high-value renewals first.
- If adoption telemetry is unavailable, explicitly state reduced confidence.
- Keep recommendations concrete and owner-assigned.
