---
name: contact-outreach-advisor
description: Recommends the best channel and time to contact someone based on CRM activity history. Use when the user asks how or when to reach a contact, or wants outreach suggestions based on past interactions.
---

# Contact Outreach Advisor

AI Agent Skill

Recommends the best channel and time to contact someone based on CRM activity history.

## Goal

Analyze communication history for one or more contacts and recommend the best outreach channel and timing.

## Steps

1. Identify contacts
- If the user names a specific contact, search for them in CRM using `enterprise_search` on Contact.
- If the user says "my contacts," query recent Events and Tasks linked to the current user (`OwnerId = <current_user_id>`) with a `WhoId`.

2. Pull communication history
- For each contact, retrieve recent Events and Tasks:
  - Events: `SELECT Id, Subject, ActivityDateTime, DurationInMinutes, Type FROM Event WHERE OwnerId = '<user_id>' AND WhoId = '<contact_id>' ORDER BY ActivityDateTime DESC LIMIT 20`
  - Tasks: `SELECT Id, Subject, ActivityDate, TaskSubtype, Type FROM Task WHERE OwnerId = '<user_id>' AND WhoId = '<contact_id>' ORDER BY ActivityDate DESC LIMIT 20`

3. Analyze patterns
- Preferred channel from dominant interaction type.
- Preferred day of week.
- Preferred time of day (`morning <10am`, `midday 10am-2pm`, `afternoon >2pm`, adjusted to user timezone).
- Interaction cadence (weekly, biweekly, monthly, ad hoc).
- Most recent interaction date.

4. Generate recommendations
- For each contact, produce:
  - Recommended channel (for example: `Video Meeting`, `Email -> Call`)
  - Best day and time
  - Suggested next outreach date based on cadence and last contact
  - One-sentence rationale

## Output Format

Return a markdown table with:

`Contact | Account | Last Contact | Cadence | Recommended Channel | Best Day & Time | Next Outreach | Rationale`

- `Contact`: use contact name as CRM link: `<span data-entity="Contact" data-record-name="Name" data-record-url="/lightning/r/Contact/&lt;id&gt;/view"></span>[Name](/lightning/r/Contact/<id>/view)`
- `Account`: account name
- `Last Contact`: `YYYY-MM-DD`
- `Cadence`: weekly / biweekly / monthly / ad hoc
- `Recommended Channel`: Video Meeting / Phone Call / Email / Slack
- `Best Day & Time`: for example `Tuesday 2:00 PM`
- `Next Outreach`: concrete date (for example `Sep 2`)
- `Rationale`: one short sentence
- If no history exists, use `No history` in activity columns and recommend `Email (first touch)`.

## Notes

- Always respect the user's local timezone (`America/Los_Angeles` by default, adapt when needed).
- For internal contacts, mention Slack as a possible primary channel.
- If history is sparse or irregular, recommend fresh outreach instead of overfitting a pattern.
