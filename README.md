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
- `jq` (usually pre-installed on macOS; `brew install jq` / `apt install
  jq` otherwise)
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

### If something goes wrong

Paste this into Claude Code and it'll diagnose it for you:

```
I'm trying to install and use the Socrates plugin for Claude Code
(https://github.com/MaikelHeijen/socrates) but something isn't working.
Please help me diagnose it:

1. Confirm the marketplace was added: run `/plugin marketplace list` and
   check "socrates" is there.
2. Confirm the plugin itself is installed, not just the marketplace: run
   `/plugin list` and check "socrates" shows as installed. If it's only
   in the marketplace list, run `/plugin install socrates@socrates`.
3. Check the prerequisites are on PATH: run `which jq` and
   `which rsvg-convert` in the terminal. If either is missing, tell me so
   I can install it (jq: `brew install jq` / `apt install jq`;
   rsvg-convert: `brew install librsvg` / `apt install librsvg2-bin`).
4. Try `/socrates:teach test topic` and tell me exactly what happens.
   "Unknown command" means step 2 above wasn't done yet; anything else,
   show me the full output so I can see what's actually failing.
5. If it starts but a permission prompt for `resolve-config.sh` or
   `svg-check.sh` keeps interrupting things, check this repo's README
   for its "Avoiding permission prompts" section.
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

## Avoiding permission prompts (optional)

Socrates' helper scripts (`resolve-config.sh`, `svg-check.sh`) run through
Claude Code's Bash tool by their full installed path, so depending on your
permission mode you may be asked to approve them the first time they run.
To pre-approve them, merge these entries into the `permissions.allow` array
in your `~/.claude/settings.json` (create the file with this content if you
don't have one yet):

```json
{
  "permissions": {
    "allow": [
      "Bash(/Users/<you>/.claude/plugins/cache/socrates/socrates/*/scripts/resolve-config.sh*)",
      "Bash(/Users/<you>/.claude/plugins/cache/socrates/socrates/*/scripts/svg-check.sh*)"
    ]
  }
}
```

Replace `<you>` with your username (on Linux, use `/home/<you>/...` instead
of `/Users/<you>/...`). Use the **full, absolute path** — `~` does not get
expanded inside a permission pattern, so a pattern starting with `~` silently
never matches and the prompt keeps appearing. The `*` before `/scripts/...`
matches the installed version segment, so this survives plugin updates. If
you're developing locally with `--plugin-dir`, substitute that directory's
absolute path instead.

A broader pattern like `Bash(*resolve-config.sh*)` also technically works,
but it's a substring match over the *entire* command string — it will also
auto-approve any unrelated command that merely contains that text somewhere
(including as a trailing comment), which is a real risk, not a theoretical
one. Prefer the path-anchored form above.

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
