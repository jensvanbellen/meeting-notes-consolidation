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

## Step 0 — Load state from Notion (do this first)

All run state lives in Notion, next to the hub, so every machine and agent sees the same
state. Nothing is read from or written to the local machine.

1. **Config page.** Search Notion for the page titled **Meeting Notes Consolidation Config**
   and fetch it. It holds:
   - The hub **database URL** and **data source URL** (`collection://<id>`).
   - The **name-normalization map** — how your recorders mishear recurring people,
     companies, and tools. Transcription garbles names consistently, so a small lookup
     fixes them.
2. **First run (no config page).** Search for the hub by name ("AI Meeting Notes Hub"),
   fetch it to get the data source URL, then create the config page as a private page with
   a `## Hub` section (both URLs) and an empty `## Name normalizations` section, in that
   order. Tell the user you created it.
3. **Window.** Derive where the last run stopped from the hub itself; there is no stored
   cursor. Query `SELECT MAX("date:Date:start") FROM "collection://<id>"` and start the
   window **48 hours before** that timestamp, ending now. The overlap is deliberate:
   recorders lag, and the Step 3 dedup skips anything already written. If the hub is empty,
   ask the user for a start date. If the user names a specific date range or meeting, honor
   that instead.

**Notion tool notes.** Plans without `ai_search` / `query_meeting_notes` must use `search` +
`query-data-sources` in SQL mode. `query-data-sources` wants the data source as
`collection://<id>` — a bare UUID errors with `Invalid data source URL` — and the SQL `FROM` is
that same `collection://<id>` string. Dates live in expanded columns `date:Date:start` /
`date:Date:is_datetime`. To fix an existing page (e.g. a mis-attributed counterpart) use
`notion-update-page` with `command: update_properties` for properties and
`command: replace_content` with a `new_str` body for the page text. To append to the config
page, use `command: insert_content` (appends at the end).

## Step 1 — Gather from every source

Pull candidate meetings from each recorder for the Step 0 window. Sources are
additive — add new recorders here as they appear; the reconciliation in Step 2 makes them
interchangeable.

- **Granola** (MCP): `list_meetings` / `query_granola_meetings` (last_30_days), then
  `get_meetings` (plural, by id) — its `summary` field is the enhanced-note body. Granola's
  enhanced note is usually the **most reliable** written record. Do **not** use
  `get_meeting_transcript` unless on a paid Granola tier; on free/basic it returns
  `Transcripts are only available to paid Granola tiers` and `get_meetings` is the way in.
- **Gemini notes** (Google Drive MCP): `search_files` with a structured query like
  `title contains 'Notes by Gemini' and modifiedTime > '<RFC3339>'` (no `order_by`, no
  doc-type words), then `read_file_content`. Gemini "not enough conversation in a
  supported language" = empty note, skip it. Gemini 1:1 transcripts are often near-useless
  audio ("Yeah… yeah") — use Gemini mainly for **attendees and titles**, not content.
- **Fathom** (MCP): `list_meetings` / `search_meetings` for the window, then
  `get_meeting_summary` (+ `get_meeting_transcript` if you need detail). Fathom summaries are
  structured — good for action items and decisions — but carry **no reliable speaker labels**
  (a bot-less capture renders everyone as "Speaker 1"), so never attribute a quote, role, or
  decision to a named person from Fathom alone. Take names from Granola or the calendar.
- **Future recorders**: same pattern — list in window, fetch summary/transcript, feed into
  Step 2.

**Recorders lag.** An ad hoc meeting can take ~30–60 min to surface in Granola/Fathom, and
Gemini longer. If the user says a meeting happened but it isn't listed, re-poll rather than
concluding it's missing. If one recorder is still processing, write the page from the
reliable sources now and note the pending one in the source line — create-only means folding
a late source in later needs an explicit update, rarely worth it for a 1:1 (Gemini is low
value there anyway).

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
- **Ad hoc / off-calendar meetings.** Not every meeting has a gcal event (impromptu calls,
  ad hoc Google Meets). With no matching event there is nothing to reconcile against: take
  attendees from the recorders, **treat the counterpart as unverified**, and say so in the
  source line. Recorder titles guess the counterpart from the audio and are often wrong — a
  note titled "with X" may name someone who was only *discussed*, not present. If the
  counterpart matters and no calendar event confirms it, **flag it to the user** instead of
  trusting the title.
- Apply the **name-normalization map** from Step 0 to fix misheard names, companies, and
  tools. If you spot a **new** mishearing that the map doesn't cover, note it — you'll add
  it back in Step 5.

## Step 3 — Dedup against Notion

Before creating anything, `search` / `query-data-sources` (SQL mode) the AI Meeting Notes
Hub for a page with the same meeting + date. **If a page already exists, SKIP it** — do not
recreate and do not overwrite. Only update an existing page if the user explicitly asks you
to (e.g. "re-do yesterday's standup note"), and even then confirm which page first.

This dedup is the **primary** guard, not a backstop: the Step 0 window overlaps the last run
on purpose, several meetings share a day, and ad hoc ones surface hours later. Always run it.
It also keeps runs from different machines safe: whichever runs second skips what the first
wrote.

## Step 4 — Write consolidated pages to Notion

Create one page per meeting in the AI Meeting Notes Hub (IDs from Step 0). Match the
existing pages' structure exactly.

**Properties:** `Meeting title` (title), `Subject` (one-line), `Date` (datetime, **store
UTC** — convert using the calendar event's own offset, not the machine's clock; set
`date:Date:start` to UTC ISO and
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

- The italic **source line goes at the bottom**, listing which recorders fed the page. For an
  off-calendar meeting, say so and name where attendees came from instead, e.g.
  `*Source: Granola & Fathom. Ad hoc meeting, not on Google Calendar; attendees per recorders.*`
- Set a **page emoji icon** that matches the topic.
- **Write each page in the meeting's own language.** If you hold meetings in more than one
  language, match it — e.g. a Dutch meeting gets a fully Dutch page (`## Samenvatting`,
  `## Volgende stappen`, `**Aanwezig:**`, `*Bron: …*`).
- Favor detail. This hub is the single source of truth, so capture decisions, rationale,
  numbers, and owners — not just headlines.

## Step 5 — Update state and report

There is no cursor to move: the next run derives its window from the hub. Append any **new
name normalizations** you found in Step 2 to the end of the config page, which is its
`## Name normalizations` section. Change nothing else on that page.

Then report to the user: which meetings were added/updated/skipped, and anything that
needed a judgment call (ambiguous title, empty note, unmatched calendar event).

## Guardrails

- **Create-only for meeting pages. This skill never overwrites or deletes an existing meeting
  page.** It uses `notion-create-pages` to add new ones. The only page it edits is the config
  page: created on first run, then appended to with new name normalizations. Two independent
  guards keep it from re-touching the hub: the Step 0 window starts from the latest meeting
  already there, and the Step 3 dedup skips any meeting already in the hub. Editing an
  existing meeting page happens only on an explicit, confirmed request.
- Never invent meeting content. If a source is empty or unintelligible, say so and rely on
  the others; if none has real content, skip the page rather than fabricate.
- Calendar wins for who/when. When recorder and calendar disagree, trust the calendar.
- Confirm before writing if the run would create a large batch (say, >10 pages) or if the
  date range is ambiguous.
