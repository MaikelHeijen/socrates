# Socrates

A Socratic AI tutor built on Claude Code. It probes what you already
know about a topic, plans a fact-checked curriculum, then teaches it to
you one reasoning step at a time — with applied-reasoning checks instead
of plain quizzes, and diagrams that a sub-agent draws and visually
checks itself before showing you.

Inspired by ["How I Use AI to Learn Things" (Eero Alvar)](https://www.youtube.com/watch?v=kzcI5F4tGiU),
rebuilt to run entirely on Claude Code — no separate paid model or API
needed.

## Prerequisites

- [Claude Code](https://claude.com/claude-code)
- `rsvg-convert`, for rendering diagrams so Socrates can check its own
  work: `brew install librsvg` (macOS) or your distro's `librsvg2-bin` /
  `librsvg` package.
- Optional: an [Obsidian](https://obsidian.md) vault, if you want
  learning sessions saved as notes you can browse and link. Without one,
  Socrates saves sessions to a local `socrates-notes/` folder instead.

## Install

```bash
/plugin marketplace add https://github.com/MaikelHeijen/socrates
/plugin install socrates@socrates
```

## Configure (optional)

If you want sessions saved into an Obsidian vault, create
`socrates.config.json` in the directory you'll run Claude Code from
(copy `socrates.config.json.example`):

```json
{
  "vault": "/absolute/path/to/your/Obsidian/vault",
  "notesRoot": "Resources"
}
```

`notesRoot` is the folder inside your vault where topic notes are
created, one subfolder per topic. Without this file, Socrates uses
`./socrates-notes/` in the current directory instead.

## Use

```
/socrates:teach differential forms
```

What happens:

1. **Probe** — a handful of quick multiple-choice questions to find out
   what you already know, and where your understanding runs out.
2. **Plan** — Socrates works out the curriculum needed to get from there
   to your goal, checks any factual claims it depends on against the
   web, and shows you the plan as a dependency graph before teaching
   anything.
3. **Teach** — one concept at a time, with an occasional diagram and a
   short scenario question after each step to check you actually
   understood it (not just recognized the right multiple-choice answer).

Sessions are saved as you go, so you can stop at any point and resume
later by running the same command again — Socrates picks up where you
left off.

## How it's built

- `skills/teach/SKILL.md` — the orchestration instructions.
- `scripts/resolve-config.sh` — finds your `socrates.config.json`.
- `scripts/svg-check.sh` — renders a diagram and hands it back so a
  sub-agent can look at what it drew.
- `hooks/socrates-banner.sh` — a startup banner, shown only inside a
  directory that's an active Socrates workspace.

## License

MIT
