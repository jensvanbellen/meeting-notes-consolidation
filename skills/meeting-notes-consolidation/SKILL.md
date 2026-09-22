---
name: meeting-notes-consolidation
description: Consolidate recent meeting notes from Granola, Gemini (Google Drive), Fathom, and any future recorder into the Notion "AI Meeting Notes Hub" — the single source of truth — verifying every meeting against Google Calendar. Use when the user says "consolidate my meeting notes", "update my Notion meeting notes", "sync meeting notes", or invokes /meeting-notes-consolidation.
user-invocable: true
metadata:
  author: jens
---

# Meeting Notes Consolidation

Gather meeting notes scattered across recorders (Granola, Gemini notes in Google Drive,
Fathom, more later), reconcile them against Google Calendar, and write one clean,
detailed Notion page per meeting into the **📝 AI Meeting Notes Hub** — the single
source of truth. Preserve as much substance as the sources allow.

## Step 0 — Load your local state (do this first)

The volatile, per-user details do not live in this skill — keep them in a **local state
file** (a notes-hub config, or a Claude Code memory) and read it before anything else. Point
the skill at yours; it should hold:

- The Notion **database + data-source IDs** for your meeting-notes hub, and the property
  schema.
- The **"Consolidated through <date>"** cursor — where the last run stopped.
- Any **tool-arg quirks** for your Notion plan (e.g. plans without `ai_search` /
  `query_meeting_notes` must use `search` + `query-data-sources` in SQL mode).
- A **name-normalization map** — how your recorders mishear recurring people, companies, and
  tools. Transcription garbles names consistently, so a small lookup fixes them.

Start this run from meetings **after** the cursor date. If the user names a specific date
range or meeting, honor that instead. See the [README](../../README.md) for how to set this
state file up.

## Step 1 — Gather from every source

Pull candidate meetings from each recorder for the window (cursor → now). Sources are
additive — add new recorders here as they appear; the reconciliation in Step 2 makes them
interchangeable.

- **Granola** (MCP): `list_meetings` / `query_granola_meetings` (last_30_days), then
  `get_meeting_transcript` for the enhanced note. Granola's enhanced note is usually the
  **most reliable** written record.
- **Gemini notes** (Google Drive MCP): `search_files` with a structured query like
  `title contains 'Notes by Gemini' and modifiedTime > '<RFC3339>'` (no `order_by`, no
  doc-type words), then `read_file_content`. Gemini "not enough conversation in a
  supported language" = empty note, skip it. Gemini 1:1 transcripts are often near-useless
  audio ("Yeah… yeah") — use Gemini mainly for **attendees and titles**, not content.
- **Fathom** (MCP): `list_meetings` / `search_meetings` for the window, then
  `get_meeting_summary` + `get_meeting_transcript`. Fathom summaries are structured — good
  for action items and decisions.
- **Future recorders**: same pattern — list in window, fetch summary/transcript, feed into
  Step 2.

## Step 2 — Reconcile against Google Calendar (source of truth)

**Google Calendar is authoritative for time, attendees, and the real meeting/counterpart.**
Recorder auto-titles are frequently wrong — a recorder names the session from whatever was
said first, not from the invite, so a 1:1 often lands under the wrong topic or the wrong
counterpart. The calendar event is the truth.

- `list_events` (uses `startTime`/`endTime`) over the window.
- Match each recorder note to a calendar event by **date + time**. Granola timestamps ≈
  Gemini's `HH:MM <TZ>` in the doc title ≈ the gcal event.
- Take the **title, attendees, and real counterpart from the calendar event**, not the
  recorder.
- **Merge** all sources for the same meeting into one page: prefer Granola/Fathom for
  content, gcal for metadata, Gemini as a fallback for attendees/title.
- Apply the **name-normalization map** from Step 0 to fix misheard names, companies, and
  tools. If you spot a **new** mishearing that the map doesn't cover, note it — you'll add
  it back in Step 5.

## Step 3 — Dedup against Notion

Before creating anything, `search` / `query-data-sources` (SQL mode) the AI Meeting Notes
Hub for a page with the same meeting + date. **If a page already exists, SKIP it** — do not
recreate and do not overwrite. Only update an existing page if the user explicitly asks you
to (e.g. "re-do yesterday's standup note"), and even then confirm which page first. The
cursor from Step 0 should already prevent reprocessing; this dedup is the backstop.

## Step 4 — Write consolidated pages to Notion

Create one page per meeting in the AI Meeting Notes Hub (IDs from Step 0). Match the
existing pages' structure exactly.

**Properties:** `Meeting title` (title), `Subject` (one-line), `Date` (datetime, **store
UTC** — convert from your local timezone; set `date:Date:start` to UTC ISO and
`date:Date:is_datetime` = 1), `Follow-up status` (one of: "To follow up" / "In progress" /
"No follow-ups" / "Done"). Adjust these to your own hub's schema.

**Page body template** (English meetings):

```
## Summary
<prose summary — as much detail as the sources support>

## <Topic>
- <bullet>
- <bullet>

## Next steps
- [ ] <action> (owner)
- [ ] <action> (owner)

**Attendees:** <names, normalized, from calendar>

---
*Source: Granola [& Fathom] [& Gemini notes: [title](url)]. Attendee and time verified against Google Calendar.*
```

- The italic **source line goes at the bottom**, listing which recorders fed the page.
- Set a **page emoji icon** that matches the topic.
- **Write each page in the meeting's own language.** If you hold meetings in more than one
  language, match it — e.g. a Dutch meeting gets a fully Dutch page (`## Samenvatting`,
  `## Volgende stappen`, `**Aanwezig:**`, `*Bron: …*`).
- Favor detail. This hub is the single source of truth, so capture decisions, rationale,
  numbers, and owners — not just headlines.

## Step 5 — Update your state (close the loop)

After a successful run, update your local state file (from Step 0):
- Move the **"Consolidated through <date>"** cursor forward to the last meeting processed,
  and keep a short list of the batch you handled.
- Append any **new name normalizations** you discovered in Step 2.

Then report to the user: which meetings were added/updated/skipped, and anything that
needed a judgment call (ambiguous title, empty note, unmatched calendar event).

## Guardrails

- **Create-only. This skill never overwrites or deletes existing Notion content.** It uses
  `notion-create-pages` to add new pages and nothing else. Two independent guards keep it
  from touching what's already there: the Step 0 cursor (only processes meetings after the
  last run) and the Step 3 dedup (skips any meeting already in the hub). Editing an existing
  page happens only on an explicit, confirmed request.
- Never invent meeting content. If a source is empty or unintelligible, say so and rely on
  the others; if none has real content, skip the page rather than fabricate.
- Calendar wins for who/when. When recorder and calendar disagree, trust the calendar.
- Confirm before writing if the run would create a large batch (say, >10 pages) or if the
  date range is ambiguous.
