# Socrates — design

## Background

Inspired by "How I Use AI to Learn Things" (Eero Alvar), which uses a
custom agent harness ("Pi") as a 1-on-1 AI tutor: a probe→plan→teach
loop with adaptive knowledge measurement, fact-checking sub-agents, a
Mermaid dependency graph as the lesson plan, and Obsidian as the
display layer.

Goal of Socrates: the same approach, but built entirely on **Claude
Code** as the LLM (no separate paid API/model needed), packaged as a
shareable Claude Code plugin, with an existing or fresh Obsidian vault
as an optional note destination.

Core principle (carried over from the video): one AI teacher
aggregates all sources and teaches through a single trusted interface,
instead of many-to-many (one course for many students; one student
juggling many sources). That solves two inefficiencies: a course that
can't be optimal for any one learner, and a learner who has to
context-switch between sources (mental cost + trust has to be rebuilt
each time). With AI, trust isn't built over time but engineered in —
hence the emphasis on verification/fact-checking.

## Scope v1

- Primarily targeted at technical/subject-matter topics with a clear
  dependency tree (math, programming, architecture patterns — not
  primarily current-events/news topics).
- Full scope including Obsidian persistence of sessions, and
  sub-agent-generated, self-checked visuals (SVG).
- Packaged as an installable, shareable Claude Code plugin — not tied
  to one specific personal vault structure.

## Architecture

Repo: `~/Developer/socrates` (standalone git project, publishable on
GitHub).

```
socrates/
├── .claude-plugin/plugin.json   ← plugin manifest (exact shape to confirm during the implementation plan)
├── skills/teach/SKILL.md        ← probe→plan→teach orchestration (/teach <topic>)
├── hooks/socrates-banner.sh     ← SessionStart hook: logo, version, skills, linked note
├── scripts/svg-check.sh         ← rsvg-convert wrapper for visual self-check of SVGs
├── socrates.config.json.example ← vault path, notes root, language
└── README.md
```

No hardcoded path or PARA structure: on first use the skill asks for
(or reads from `socrates.config.json`) where the vault lives and which
notes root to use (default `Resources`). Without a configured vault,
the skill falls back to a local folder `./socrates-notes/` in the
current working directory, with a one-time warning.

## Components

1. **`teach` skill** (`skills/teach/SKILL.md`) — orchestrates
   probe/plan/teach per the session flow below, reads/writes the
   working note, maintains the understanding map.
2. **Assess mechanism** — two check types (see below), no separate
   tool needed: calibration checks via the existing `AskUserQuestion`
   tool, applied checks via plain chat text.
3. **Research sub-agent** — spawned via the `Agent` tool during the
   Plan phase, using `WebSearch`/`WebFetch`, to verify
   factual/technical claims in the draft curriculum before the plan is
   finalized.
4. **Visualization sub-agent** — spawned via `Agent` during Teach,
   writes an SVG, renders it via `scripts/svg-check.sh`
   (`rsvg-convert`) to PNG, inspects the result with the `Read` tool,
   corrects until it's right (max. 1 retry, see Error handling), and
   embeds it in the working note.
5. **Working note** — `<notes-root>/<topic>/<Topic>.md` (or
   `./socrates-notes/<Topic>.md` without a vault): holds the
   understanding map, Mermaid plan, progress marker, session log,
   embedded visuals.
6. **Banner hook** (`hooks/socrates-banner.sh`) — cosmetic, cwd-scoped
   (only active inside the Socrates project), shows an ASCII logo
   (a Doric column in block characters), version, available skills,
   and the path of the linked working note at session start — in the
   same spirit as Pi's startup screen.

## Assess mechanism: calibration vs. applied checks

Two complementary check types, so the system can both calibrate
quickly and validate deeply without needing a real practice
environment:

- **Calibration check** — a quick multiple-choice question via
  `AskUserQuestion`. Used in the Probe phase: for each dependency
  strand, binary-search upward (from basic to advanced) until the
  first incorrectly answered question; everything below that point on
  the strand counts as known, everything from that point on goes onto
  the to-teach list. Other strands start at their own, independent
  level. Fast, broad coverage, suited to warm-up.
- **Applied check** — after explaining a concept in the Teach phase,
  the learner doesn't get an MC question but a scenario/thought
  experiment ("suppose that...", "what would you expect if...") that
  can be fully reasoned through mentally, with no external tools or
  environment required. The answer is given in free text, including
  the reasoning — not via clickable options, since a reasoning trace
  doesn't fit into 2-4 choices. Socrates evaluates not just the
  conclusion but the reasoning itself: a conclusion that's right by
  coincidence despite a wrong intermediate step is flagged as such,
  and so is a wrong conclusion built on an otherwise sound line of
  reasoning.

**Where used**: calibration checks primarily in Probe; applied checks
primarily in Teach, after each step. On a borderline answer during
Probe, Socrates may exceptionally fire off one applied check to verify
an MC answer — this is the exception, not the rule, to keep the
warm-up fast.

**Understanding map** tracks, per concept: status (`known` /
`partial` / `unknown`), how that was established (`calibration` /
`applied`), and for applied checks, a short note of the specific
misconception if one occurred. A "known" status backed only by a
calibration guess carries less weight than one confirmed by an applied
check — relevant when deciding whether a strand is truly complete.

## Session flow

- **New topic** (no working note): Probe (calibration checks,
  binary-search per strand) → understanding map → Plan (draft
  curriculum + research sub-agent verifies claims + corrections
  applied + Mermaid dependency graph) → write working note → Teach
  begins.
- **Resume** (working note exists): read the understanding map and
  progress marker, skip Probe, resume Teach at the last completed
  node.
- **Teach**: explain one node at a time; optionally a visual via the
  visualization sub-agent; an applied check on that node; update the
  understanding map, progress marker, and session log in the working
  note immediately after each step (not only at the end), so a session
  can always be safely interrupted and resumed mid-way.
- **Closing**: no separate wrap-up step — the working note simply
  remains as a permanent note, the same way existing reference notes
  in a vault grow organically over time.

## Error handling

- Research sub-agent fails or times out → the Plan phase continues,
  the claim in question gets a `⚠ unverified` marker in the working
  note instead of blocking the whole flow.
- Visualization sub-agent fails (e.g. model timeout, like "agent
  overloaded" in the video) → one retry; if it still fails, the visual
  is skipped and the text explanation continues, with
  `[visual skipped]` noted in the working note.
- No configured vault found → fall back to the local folder
  `./socrates-notes/`, warn once, don't repeat within the same
  session.

## Packaging & sharing

- Distributed via a git repo, structured per Claude Code plugin
  conventions (exact manifest shape to be verified while writing the
  implementation plan, not assumed in this document).
- `README.md` covers: prerequisites (Claude Code, `brew install
  librsvg` for `rsvg-convert`, optionally an Obsidian vault),
  installation steps, first-time configuration, and a short
  explanation of the probe/plan/teach flow so someone who hasn't seen
  the source video still understands what's happening.
- No personal vault content, session-log hooks, or git-autocommit
  hooks from the author are included — that's a separate, personal
  system, not part of this plugin.

## Testing

- Smoke test: run `/teach` on a real technical topic end-to-end
  (probe → plan → at least a few teach steps including one visual and
  one applied check).
- Test `scripts/svg-check.sh` standalone with a sample SVG: confirm a
  PNG is produced and viewable with the `Read` tool.
- Banner hook: confirm it only appears inside the Socrates project,
  not in other Claude Code sessions.
- Resumability: interrupt a session mid-Teach, restart, confirm the
  correct node and understanding-map state are resumed.
- Fallback path: run `/teach` without a configured vault, confirm
  `./socrates-notes/` is used correctly with the one-time warning.

## Out of scope (v1)

- Voice input/dictation (Pi's `dictate` extension).
- PDF reader, youtube-transcript, web-debug, analyze-sessions as
  separate skills (Pi has these alongside `teach`; Socrates v1 focuses
  purely on the tutor flow).
- Round-tripping quizzes through an Obsidian file (deliberately not
  chosen — chat-based is faster).
