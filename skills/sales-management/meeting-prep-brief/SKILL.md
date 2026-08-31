---
name: meeting-prep-brief
description: Generates a structured pre-meeting brief using CRM context, opportunity history, stakeholder activity, and open risks. Use when the user asks to prepare for a customer or prospect meeting, account review, QBR, or deal strategy call.
---

# Meeting Prep Brief

AI Agent Skill

Generates a concise, actionable pre-meeting pack for a specific account, opportunity, or contact using Salesforce data.

## Goal

Help the user walk into a meeting with the right context, risks, and next-step recommendations.

## Steps

1. Identify meeting context
- Collect what is known: account name, opportunity name, contact name, meeting date, and meeting type (discovery, progression, negotiation, renewal, escalation, QBR).
- If identifiers are missing, ask for only the minimum needed to find records.

2. Resolve records
- Find the relevant Account, Opportunity, and primary Contacts.
- If multiple records match, disambiguate before continuing.

3. Gather current business context
- Opportunity: stage, amount, close date, forecast category, last modified date, owner.
- Account: segment/tier, industry, recent case volume, renewal flags if available.
- Activities: recent Events and Tasks for the account and key contacts (last 30-60 days).

4. Build stakeholder snapshot
- List key participants and their inferred role (economic buyer, champion, evaluator, blocker, unknown).
- Note relationship strength from recency/frequency of activity.
- Flag missing stakeholder coverage when the deal appears single-threaded.

5. Detect risk and momentum signals
- Stage aging beyond normal expectation.
- No meaningful activity in recent period.
- Missing or vague next step.
- Close date slippage pattern.
- Open support/escalation cases that can affect meeting tone.

6. Recommend meeting strategy
- Define top 3 meeting objectives.
- Suggest 3-5 tailored questions to ask.
- Propose one primary call-to-action for the end of the meeting.
- Provide a fallback plan if risk signals are high.

7. Draft immediate follow-up plan
- Recommend post-meeting actions with owners and target dates.
- Include a suggested follow-up email outline.

## Output Format

Return this structure:

### Meeting Brief
- Meeting: `<meeting type>` on `<date/time>`
- Account: `<account>`
- Opportunity: `<opportunity>` (Stage: `<stage>`, Amount: `<amount>`, Close: `<date>`)
- Primary Contacts: `<name + role>`

### What Changed Recently
- 3-6 bullets describing notable changes from recent activities, field updates, or support signals.

### Stakeholder Map
- Participant | Role in deal | Engagement strength | Notes

### Risks to Address
- Risk | Severity (High/Medium/Low) | Evidence | Mitigation

### Recommended Meeting Plan
- Objectives:
  1) ...
  2) ...
  3) ...
- Questions to ask:
  - ...
  - ...
  - ...
- Target outcome: `<specific commitment or next step>`

### Post-Meeting Actions
- Action | Owner | Due date | Why it matters

### Suggested Follow-Up Email
- Subject:
- Body (short draft):

## Notes

- Prefer concise bullets over long paragraphs.
- If data is missing, explicitly mark assumptions instead of guessing.
- If there is no opportunity context, still produce an account/contact-centered brief.
