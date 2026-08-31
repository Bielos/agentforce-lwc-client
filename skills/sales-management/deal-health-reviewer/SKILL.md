---
name: deal-health-reviewer
description: Scores opportunity health using CRM signals like stage progression, activity quality, stakeholder coverage, close-date confidence, and execution hygiene. Use when the user asks for deal risk assessment, pipeline risk review, forecast confidence, or next-best actions for opportunities.
---

# Deal Health Reviewer

AI Agent Skill

Analyzes one or more Salesforce opportunities and returns a health score, risk diagnosis, and prioritized recovery plan.

## Goal

Provide a clear, evidence-backed view of deal quality and the fastest actions to improve win probability.

## Steps

1. Select scope
- Identify whether the user wants one deal, a rep's pipeline, or a filtered segment (stage, region, close month, forecast category).
- Confirm time horizon for forecast-sensitive views (for example: current quarter).

2. Retrieve core opportunity data
- For each opportunity, gather: stage, amount, close date, owner, forecast category, created date, last modified date, next step, and probability if available.
- Pull recent related activities (Events/Tasks), key contacts, and major case/escalation signals tied to the account.

3. Score health dimensions (0-100 each)
- **Momentum**: activity recency and meaningful progression.
- **Stage quality**: evidence that exit criteria for the current stage are met.
- **Stakeholder coverage**: breadth and depth across decision roles.
- **Execution hygiene**: close date realism, defined next step, owner discipline.
- **Commercial confidence**: budget/timeline/procurement confidence from available notes and fields.

4. Compute overall score
- Weighted score recommendation:
  - Momentum: 25%
  - Stage quality: 25%
  - Stakeholder coverage: 20%
  - Execution hygiene: 15%
  - Commercial confidence: 15%
- Normalize to a 0-100 overall health score.
- Classify:
  - 80-100: Healthy
  - 60-79: Watchlist
  - 0-59: At Risk

5. Explain top risk drivers
- For each opportunity, list the top 2-4 risks with direct evidence (field values, activity gaps, stage age, missing roles, slip pattern).
- Avoid generic advice; tie every claim to observed data.

6. Recommend recovery actions
- Return 3-5 prioritized actions with owners and timing.
- Ensure each action is concrete, testable, and aligned to the risk source.
- Include one "fast win" action that can be executed within 24-48 hours.

7. Provide forecast lens
- Flag opportunities whose score conflicts with forecast category (for example, Commit but At Risk).
- Suggest forecast recategorization when evidence supports it.

## Output Format

For multiple opportunities, return a table first, then detailed drill-down.

### Portfolio View
Opportunity | Stage | Amount | Close Date | Health Score | Status | Top Risk | Next Best Action

### Opportunity Drill-Down
For each opportunity:
- Overall score: `<0-100>` (`Healthy` | `Watchlist` | `At Risk`)
- Dimension scores:
  - Momentum: `<score>`
  - Stage quality: `<score>`
  - Stakeholder coverage: `<score>`
  - Execution hygiene: `<score>`
  - Commercial confidence: `<score>`
- Key risks:
  1) `<risk>` - evidence: `<specific signal>`
  2) `<risk>` - evidence: `<specific signal>`
- Recovery plan:
  1) `<action>` (Owner: `<name>`, Due: `<date>`)
  2) `<action>` (Owner: `<name>`, Due: `<date>`)
  3) `<action>` (Owner: `<name>`, Due: `<date>`)
- Forecast note: `<keep or adjust category with rationale>`

## Notes

- If opportunity data is sparse, lower confidence and state the missing fields needed for a stronger assessment.
- When reviewing many deals, prioritize showing the bottom decile and largest-amount at-risk deals first.
- Keep language direct and operator-friendly: diagnose, then prescribe.
