# meeting-notes-consolidation

A `/meeting-notes-consolidation` skill for Claude Code, Codex, and omp. It gathers your
recent meeting notes from multiple recorders — Granola, Gemini (Google Drive), Fathom, and
any you add later — reconciles each against Google Calendar (the source of truth for
time, attendees, and the real topic), and writes one clean, detailed page per meeting
into your Notion meeting-notes hub. Create-only: it never overwrites or deletes
existing pages.

## Requirements

Any agent that can load a `SKILL.md` (Claude Code, Codex, omp, …) plus MCP servers for the
sources you use:

- **Granola**, **Fathom** — meeting recorders
- **Google Drive** — for "Notes by Gemini" docs
- **Google Calendar** — reconciliation / source of truth
- **Notion** — the destination hub

Any subset works; the skill treats sources as additive. The tool names in the skill (e.g.
`list_events`, `query-data-sources`) are illustrative — the exact names come from whichever
MCP servers your agent has loaded, so wire the equivalent tools in Codex/omp.

Granola, Fathom, and Notion run as standalone/local MCP servers, so they work anywhere
(Claude, Codex, omp). Google Calendar and Google Drive are typically Claude account
connectors — if your agent lacks them (omp does), you can still consolidate the recorders
you have (e.g. Granola + Fathom → Notion), but you lose calendar reconciliation and Gemini
(Drive) notes until you add standalone Google MCP servers.

## Install

```bash
git clone https://github.com/jensvanbellen/meeting-notes-consolidation.git && cd meeting-notes-consolidation && ./install.sh
```

| Tool | Location | Invoke |
|------|----------|--------|
| Claude Code | `~/.claude/skills/meeting-notes-consolidation` | `/meeting-notes-consolidation` |
| Codex | `~/.codex/skills/meeting-notes-consolidation` + `~/.codex/prompts/meeting-notes-consolidation.md` | `/meeting-notes-consolidation` |
| omp (Oh My Pi) | reads `~/.claude/skills` (needs `skills.enableClaudeUser: true`) | auto-loaded |

`install.sh` symlinks the one `SKILL.md` into Claude Code and Codex — no drift — and adds a
thin Codex prompt so the slash command works there too. omp needs no separate step: it reads
`~/.claude/skills` directly. Edits to this repo take effect immediately.
`./install.sh --uninstall` removes the links.

## Local state file (set this up once)

The per-user, changing details stay out of the skill so it can be shared. Keep them in
a **local state file** the skill reads at Step 0 — a Claude Code memory works well. Put
in it:

- Your Notion **hub database + data-source IDs** and property schema.
- A **"Consolidated through &lt;date&gt;"** cursor — where the last run stopped, so the
  next run only picks up newer meetings.
- Any **Notion tool-arg quirks** for your plan (e.g. plans without `ai_search` must use
  `search` + `query-data-sources` in SQL mode).
- A **name-normalization map** — recorders mishear recurring names the same way every
  time (`"Jure" → Djurre`); a small lookup fixes them.

The skill advances the cursor and appends new normalizations after each run.

## Usage

| Command | What happens |
|---------|--------------|
| `/meeting-notes-consolidation` | Consolidates every meeting since the cursor |
| `/meeting-notes-consolidation last week` | Restricts to a date range |
| `/meeting-notes-consolidation the Monday standup` | A single named meeting |

## How it works

1. **Load state** — Notion IDs, cursor, normalizations (above).
2. **Gather** — pull candidate meetings from each recorder for the window.
3. **Reconcile against Google Calendar** — calendar wins for time, attendees, and the
   real counterpart; recorder auto-titles are often wrong.
4. **Dedup** — skip any meeting already in the hub.
5. **Write** — one detailed page per meeting, in the meeting's own language, with a
   source line citing which recorders fed it.
6. **Update state** — advance the cursor, record new normalizations.

## Design decisions

- **Create-only, two guards.** The cursor and the dedup step both stop it re-touching
  existing pages; it only ever adds new ones. No accidental overwrites.
- **Calendar is the source of truth.** Recorders name a session from whatever was said
  first, not the invite, so titles and counterparts drift. The calendar corrects them.
- **Sources are additive.** Add a recorder by describing how to list and fetch from it;
  the calendar reconciliation makes them interchangeable.
- **Personal state lives outside the skill**, so the workflow is shareable while your
  hub IDs and colleague-name map stay yours.

## Repo layout

```
skills/meeting-notes-consolidation/SKILL.md   # the skill
install.sh                                    # symlinks into ~/.claude/skills
```

## License

Licensed under the [MIT License](LICENSE).
