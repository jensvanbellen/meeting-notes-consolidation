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

Granola and Notion run as remote MCP servers, so they work anywhere (Claude, Codex, omp).
Google Calendar, Google Drive, and Fathom are available as claude.ai connectors, which
follow your Claude account to every machine you log in on. If your agent lacks the Google
connectors (omp does), you can still consolidate the recorders you have (e.g. Granola +
Fathom → Notion), but you lose calendar reconciliation and Gemini (Drive) notes until you
add standalone Google MCP servers.

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

## State lives in Notion

The skill keeps no local state, so it runs the same from any machine or agent that can
reach your Notion. Everything it needs sits next to the hub:

- **The hub itself is the cursor.** Each run starts 48 hours before the latest `Date` in
  the hub and ends now. Nothing to advance, so two machines can never disagree. The dedup
  step skips meetings already written, which makes the overlap safe.
- **A config page** titled `Meeting Notes Consolidation Config` holds the hub database and
  data-source URLs plus a **name-normalization map**. Recorders mishear recurring names the
  same way every time (`"Jure" → Djurre`, `"Blanco"/"Branco" → Branko`); a small lookup
  fixes them. The skill creates the page on first run and appends new normalizations after
  each run.

## Usage

| Command | What happens |
|---------|--------------|
| `/meeting-notes-consolidation` | Consolidates every meeting since the latest one in the hub |
| `/meeting-notes-consolidation last week` | Restricts to a date range |
| `/meeting-notes-consolidation the Monday standup` | A single named meeting |

## How it works

1. **Load state** — config page from Notion; window from the hub's latest meeting.
2. **Gather** — pull candidate meetings from each recorder for the window.
3. **Reconcile against Google Calendar** — calendar wins for time, attendees, and the
   real counterpart; recorder auto-titles are often wrong.
4. **Dedup** — skip any meeting already in the hub.
5. **Write** — one detailed page per meeting, in the meeting's own language, with a
   source line citing which recorders fed it.
6. **Update state** — append new normalizations to the config page.

## Design decisions

- **Create-only, two guards.** The hub-derived window and the dedup step both stop it
  re-touching existing meeting pages; it only ever adds new ones. The config page is the
  one page it edits, and only by appending.
- **No local state.** A cursor in a local file or agent memory is stuck on one machine,
  and alternating machines forks it. Deriving the window from the hub keeps one truth.
- **Calendar is the source of truth.** Recorders name a session from whatever was said
  first, not the invite, so titles and counterparts drift. The calendar corrects them.
- **Sources are additive.** Add a recorder by describing how to list and fetch from it;
  the calendar reconciliation makes them interchangeable.
- **Personal state lives outside the skill**, in your own Notion, so the workflow is
  shareable while your hub IDs and colleague-name map stay yours.

## Repo layout

```
skills/meeting-notes-consolidation/SKILL.md   # the skill
install.sh                                    # symlinks into ~/.claude/skills
```

## License

Licensed under the [MIT License](LICENSE).
