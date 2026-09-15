# Importing Sample Conversations

How to bulk-load `Sample_Conversation__c` records with the **standard Salesforce
APIs** — no custom endpoints required. Use this to seed a library of scripted
conversations (for the [Sample Conversation Player](./README.md#sample-conversations-rehearse--refine-agent-responses))
from a spreadsheet, another org, or a generation pipeline.

All examples target API version **v67.0**.

## Object and fields

| Field (API name)    | Type           | Required | Notes                                                                                |
| ------------------- | -------------- | -------- | ------------------------------------------------------------------------------------ |
| `Name`              | Text           | Yes      | Standard Name field — a short title for the conversation.                            |
| `Transcript__c`     | Long Text Area | No       | The multi-turn dialogue. Each turn is a block prefixed `User:` or `Agent:`.          |
| `Skill_API_Name__c` | Text (255)     | No       | `DeveloperName` of the `Coworker_Skill__mdt` that seeds the agent.                   |
| `Agent_API_Name__c` | Text (255)     | No       | `BotDefinition` DeveloperName the transcript is played against (e.g. `SearchAgent`). |
| `Description__c`    | Text Area      | No       | One-line summary of the scenario.                                                    |

### Transcript format

The player parses turns from lines that start with `User:` or `Agent:` (case
insensitive); everything until the next such line belongs to that turn. So a
transcript field value looks like:

```
User: My order #1234 arrived damaged. What are my options?

Agent: (expected) Acknowledge, apologize, and offer a replacement or refund with an ETA.

User: I would prefer a replacement.

Agent: (expected) Confirm the replacement, restate the ETA, and provide a tracking reference.
```

Because the transcript contains **line breaks**, escape it correctly for whichever
transport you use:

- **CSV** — keep **one physical row per record** and encode turn breaks as `\n`
  (use `\r\n` if you have CRLF). Quote the field if it contains commas; escape
  any literal `"` as `""`. Salesforce stores those `\n` sequences as text; the
  Sample Conversation Player expands them into real line breaks when it parses
  turns. RFC 4180 quoted real newlines also work with Bulk API, but spreadsheets
  and copy-paste often mangle them — prefer `\n`.
- **JSON** (REST / `sf data import tree`) — encode newlines as `\n`.

## Permissions

The importing user needs create access and field-level security on the object.
Assign the shipped permission set once:

```bash
sf org assign permset --name SampleConversationAccess
```

(Or grant equivalent CRUD/FLS on `Sample_Conversation__c` through a profile.)

---

## Option A — `sf` CLI (Salesforce CLI, easiest)

The CLI wraps the REST and Bulk APIs. Good for one-off and CI loads.

### A1. Small/medium loads from CSV (REST under the hood)

`sample-conversations.csv`:

```csv
Name,Skill_API_Name__c,Agent_API_Name__c,Description__c,Transcript__c
"Late order complaint","manage_customer_complaints","SearchAgent","Damaged order; replace or refund","User: My order #1234 arrived damaged. What are my options?\n\nAgent: (expected) Acknowledge, apologize, and offer a replacement or refund with an ETA."
"Password reset","account_help","SearchAgent","User cannot log in","User: I can't log into my account.\n\nAgent: (expected) Offer a secure reset link and confirm identity."
```

Each transcript stays on a single CSV row. The `\n` sequences are the encoded
character returns — do not insert a real line break inside the field unless you
are deliberately using RFC 4180 quoting.

Import it:

```bash
sf data import bulk \
  --sobject Sample_Conversation__c \
  --file sample-conversations.csv \
  --wait 10
```

For a few records you can also use the synchronous path:

```bash
sf data create record --sobject Sample_Conversation__c \
  --values "Name='Late order complaint' Agent_API_Name__c='SearchAgent' Skill_API_Name__c='manage_customer_complaints' Transcript__c='User: ...\n\nAgent: ...'"
```

### A2. Repeatable seed data with `sf data import tree`

Store the records as JSON in the repo and re-import them into any scratch org or
sandbox. `data/Sample_Conversation__c.json`:

```json
{
  "records": [
    {
      "attributes": { "type": "Sample_Conversation__c", "referenceId": "SC_1" },
      "Name": "Late order complaint",
      "Skill_API_Name__c": "manage_customer_complaints",
      "Agent_API_Name__c": "SearchAgent",
      "Description__c": "Damaged order; replace or refund",
      "Transcript__c": "User: My order #1234 arrived damaged. What are my options?\n\nAgent: (expected) Acknowledge, apologize, and offer a replacement or refund with an ETA."
    }
  ]
}
```

```bash
sf data import tree --files data/Sample_Conversation__c.json
```

---

## Option B — Bulk API 2.0 (large volumes, CSV)

Best for thousands of rows. Three REST calls: create a job, upload CSV, close it;
Salesforce processes asynchronously. Get `${ACCESS_TOKEN}` and `${INSTANCE_URL}`
from `sf org display --json`.

```bash
# 1) Create an ingest job
JOB=$(curl -s -X POST "${INSTANCE_URL}/services/data/v67.0/jobs/ingest" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"object":"Sample_Conversation__c","contentType":"CSV","operation":"insert","lineEnding":"LF"}')
JOB_ID=$(echo "$JOB" | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")

# 2) Upload the CSV batch (same columns/quoting as Option A)
curl -s -X PUT "${INSTANCE_URL}/services/data/v67.0/jobs/ingest/${JOB_ID}/batches" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: text/csv" \
  --data-binary @sample-conversations.csv

# 3) Mark the job ready for processing
curl -s -X PATCH "${INSTANCE_URL}/services/data/v67.0/jobs/ingest/${JOB_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"state":"UploadComplete"}'
```

Poll `GET /jobs/ingest/${JOB_ID}` for state `JobComplete`, then read
`/successfulResults` and `/failedResults` for row outcomes. Set `lineEnding` to
`LF` or `CRLF` to match your file. Prefer one physical row per record with `\n`
inside `Transcript__c`; if you instead embed real newlines, quote those fields.

---

## Option C — REST API (record-at-a-time or Composite)

### C1. Single record (sObject Rows)

```bash
curl -s -X POST "${INSTANCE_URL}/services/data/v67.0/sobjects/Sample_Conversation__c" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
        "Name": "Late order complaint",
        "Skill_API_Name__c": "manage_customer_complaints",
        "Agent_API_Name__c": "SearchAgent",
        "Description__c": "Damaged order; replace or refund",
        "Transcript__c": "User: My order #1234 arrived damaged.\n\nAgent: (expected) Acknowledge and offer options."
      }'
```

### C2. Up to 200 records in one call (Composite sObject Collections)

```bash
curl -s -X POST "${INSTANCE_URL}/services/data/v67.0/composite/sobjects" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
        "allOrNone": false,
        "records": [
          { "attributes": {"type":"Sample_Conversation__c"},
            "Name":"Late order complaint",
            "Agent_API_Name__c":"SearchAgent",
            "Transcript__c":"User: ...\n\nAgent: ..." },
          { "attributes": {"type":"Sample_Conversation__c"},
            "Name":"Password reset",
            "Agent_API_Name__c":"SearchAgent",
            "Transcript__c":"User: ...\n\nAgent: ..." }
        ]
      }'
```

---

## Option D — Point-and-click (no code)

- **Data Import Wizard** (Setup → Data Import Wizard → _Custom objects_ →
  _Sample Conversations_) — map the CSV columns to the fields above. Fine for
  modest volumes; use `\n` in `Transcript__c` so each record is one CSV row.
- **Data Loader** (desktop app) — choose **Insert**, select
  `Sample_Conversation__c`, map columns, run. It uses Bulk/REST under the hood.
  Same advice: encode turn breaks as `\n` rather than embedding real line breaks.

---

## Verify the import

```bash
sf data query --query "SELECT Name, Agent_API_Name__c, Skill_API_Name__c, Description__c FROM Sample_Conversation__c ORDER BY CreatedDate DESC"
```

Then open a record in the **Agent Skills** app → **Sample Conversations** tab and
confirm the player parses the turns (each `User:`/`Agent:` block becomes a turn).

## Tips and gotchas

- **Turn prefixes matter.** If a transcript imports but the player shows "No turns
  yet", the text is missing `User:` / `Agent:` line prefixes — the parser keys off
  them.
- **Newlines are the #1 CSV pitfall.** Salesforce does **not** turn a `\n`
  sequence into a real line break on import — it stores the two characters.
  Encode turn breaks as `\n` on a single CSV row anyway; the player expands
  them. A transcript with neither real newlines nor `\n` between `User:` /
  `Agent:` blocks collapses into a single turn.
- **Skill / Agent are plain text**, not lookups — store the exact
  `Coworker_Skill__mdt` `DeveloperName` and `BotDefinition` DeveloperName. A typo
  simply means the player can't resolve the skill/agent at play time.
- **Upserts:** to update existing rows instead of inserting duplicates, add an
  External Id field to the object and use the upsert variants
  (`sf data upsert bulk --external-id <field>`, or the Bulk 2.0 `upsert`
  operation). The object ships without one, so inserts create new records.

```

```
