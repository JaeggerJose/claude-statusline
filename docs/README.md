# `csl` / Status-Line Theming — Design Docs

Design notes and architecture survey for the Claude Code status-line theming
system and its evolution into a **themepack package manager** (`apt`/`pip`/`npm`/
`brew`/`claude-swap` philosophy).

## Index

| Doc | What it covers |
|-----|----------------|
| [00-architecture-survey.md](00-architecture-survey.md) | **As-is.** How the system works today: data flow, key files, the theme contract, the four ART_MODEs, the art pipeline (chafa/U+2800), and the gaps that motivate a package manager. |
| [01-package-manager-design.md](01-package-manager-design.md) | **To-be.** The six pillars of a package manager, the "themepack" unit + `manifest.json` schema, git-tap registry, the apt/npm→csl command map, lockfile, and a no-big-bang migration path. |

## TL;DR philosophy

> A theme stops being a *file you hand-edit* and becomes a *package you install,
> build, and activate* — described by a **manifest**, fetched from a **registry**,
> and reproducible from a **recipe**.

`csl` already nails *activation* (`csl set` rewrites `settings.json`). The work
ahead adds the missing pillars: **manifest** (structured metadata), **registry**
(git taps), **recipe↔artifact** separation (`art/` → `build/`), and the
**lifecycle verbs** (search/install/build/upgrade/remove/doctor).

## Related (outside this folder)

- `~/.claude/statusline/lib/render.sh` — shared renderer + theme contract
- `~/.claude/statusline/run.sh` — theme engine
- `~/.claude/statusline/themes/` — current themes (one `.sh` each)
- `~/.local/bin/csl` — the CLI being evolved
- `~/.claude/statusline-gen-art.sh` — image/GIF → ANSI frame generator
- `~/.claude/statusline-art/bastille/make_bastille.py` — the Bastille Day art recipe
