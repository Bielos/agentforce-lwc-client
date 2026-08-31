---
name: mutual-action-plan-builder
description: Builds buyer-facing mutual action plans for active opportunities, with shared milestones, owners, due dates, dependencies, and exit criteria. Use when the user asks to create a close plan, align stakeholders, prevent deal slippage, or coordinate next steps with a customer.
---

# Mutual Action Plan Builder

AI Agent Skill

Creates a structured, externally shareable plan that aligns seller and buyer teams on the path to a successful decision.

## Goal

Turn uncertain deal progression into a clear execution plan with accountability, dates, and measurable checkpoints.

## Steps

1. Identify opportunity and timeline
- Resolve the target opportunity and confirm target close window.
- Capture critical constraints: procurement cycle, legal/security review, implementation timing, and budget deadlines.

2. Map stakeholders and ownership
- Identify core participants on both sides (seller and buyer).
- Assign a primary owner for each workstream (business, technical, security, procurement, legal, executive).
- Flag missing owners as a risk.

3. Define close-critical milestones
- Build milestones that must be completed to reach decision and signature.
- Include clear entry/exit criteria for each milestone.
- Typical milestones:
  - Discovery complete and success criteria agreed
  - Solution fit validated
  - Security/legal review completed
  - Commercial terms aligned
  - Final approval and signature

4. Sequence dependencies
- For each milestone, define prerequisite items and blockers.
- Mark path-critical items that could delay close if missed.

5. Set dates and confidence levels
- Assign target dates for every milestone.
- Add confidence (High/Medium/Low) for each date based on available evidence.
- If confidence is low, propose mitigation actions.

6. Create communication cadence
- Recommend checkpoint rhythm (weekly working session, biweekly exec sync, ad hoc blocker reviews).
- Define what updates are expected at each checkpoint.

7. Produce customer-shareable plan + internal operating view
- External view: concise table for the customer.
- Internal view: risk annotations, fallback path, and escalation triggers.

## Output Format

### Mutual Action Plan (Customer View)
Milestone | Owner (Buyer/Seller) | Target Date | Exit Criteria | Status

### Dependency and Risk Notes (Internal)
- Milestone: `<name>`
  - Dependencies: `...`
  - Risk level: `High/Medium/Low`
  - Risk evidence: `...`
  - Mitigation action: `...`

### Weekly Operating Cadence
- Checkpoint day/time:
- Required attendees:
- Agenda:
  1) Milestone progress
  2) New blockers
  3) Date-risk review
  4) Next-week commitments

### Escalation Triggers
- Trigger | Escalate to | SLA

### Buyer Message Draft
- Subject:
- Body (short, collaborative tone requesting alignment on the MAP):

## Notes

- Keep milestones outcome-based, not activity-based.
- Use specific dates instead of vague labels like "next week."
- If the deal lacks buyer commitment, include a "Mutual Commitment Confirmation" milestone first.
