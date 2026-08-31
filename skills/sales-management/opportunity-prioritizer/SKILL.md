---
name: opportunity-prioritizer
description: Prioritizes opportunities by expected business return, win likelihood, execution effort, and timing sensitivity. Use when the user asks which deals to focus on first, how to allocate rep time, or how to sequence opportunity work for maximum impact.
---

# Opportunity Prioritizer

AI Agent Skill

Ranks opportunities so reps and managers can focus time on deals with the highest expected payoff.

## Goal

Convert a long opportunity list into a clear execution order with rationale and next actions.

## Steps

1. Define prioritization scope
- Confirm whether prioritization is for one rep, a team, or a segment.
- Confirm planning horizon (this week, this month, this quarter).

2. Gather deal inputs
- For each opportunity, capture: amount, stage, close date, forecast category, owner, recent activity, next step quality, and known blockers.
- Add account context signals when available (support friction, sponsor stability, strategic fit).

3. Score each opportunity
- Compute normalized scores (0-100) for:
  - Expected value (size x confidence)
  - Win likelihood (stage quality + momentum + stakeholder coverage)
  - Time criticality (close proximity, slipping risk, dependency deadlines)
  - Effort efficiency (estimated effort to move deal forward)
  - Strategic value (logo, expansion potential, product fit)

4. Calculate priority index
- Suggested weighting:
  - Expected value: 30%
  - Win likelihood: 30%
  - Time criticality: 20%
  - Effort efficiency: 10%
  - Strategic value: 10%
- Convert to final `Priority Index` (0-100).
- Assign tier:
  - Tier 1 (80-100): Immediate focus
  - Tier 2 (60-79): Active management
  - Tier 3 (0-59): Maintain or deprioritize

5. Produce action-oriented ranking
- Sort by tier, then by revenue impact.
- For each top-ranked opportunity, include one next best action and one unblock action.

6. Balance portfolio workload
- Flag if too much effort is concentrated in low-probability deals.
- Recommend time allocation split across tiers.

## Output Format

### Prioritized Opportunity List
Opportunity | Amount | Stage | Close Date | Priority Index | Tier | Next Best Action | Unblock Action

### Focus Guidance
- This week top focus (3-5 deals):
  - `<deal>` - `<reason>` - `<next action>`
- Watchlist (needs intervention):
  - `<deal>` - `<risk>` - `<intervention owner>`
- Deprioritize for now:
  - `<deal>` - `<why>`

### Suggested Time Allocation
- Tier 1:
- Tier 2:
- Tier 3:

## Notes

- Prefer simple, explainable scoring over opaque formulas.
- If critical fields are missing, mark score confidence as Low.
- Keep recommendations execution-ready for the next 5 business days.
