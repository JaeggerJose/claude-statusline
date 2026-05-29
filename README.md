# claude-statusline

A theme system **and** a package-manager-style CLI (`csl`) for the
[Claude Code](https://docs.claude.com/en/docs/claude-code) status line —
pixel-art galleries, color palettes, and shareable *themepacks*.

Switching a theme rewrites `~/.claude/settings.json → statusLine.command`, so
**settings.json is the single source of truth** for what's active (claude-swap
style — no daemon, no extra state file).

```
$ csl list
Status line themes  (~/.claude/statusline/themes)
    bastille-day  1.0.0   14 juillet — dusk-fireworks postcard: Eiffel Tower, tricolore, lavender, Bordeaux oysters …
  * maplestory    1.0.0   Rotating MapleStory sprite gallery + Catppuccin palette
    nord          1.0.0   No art, cool Nord 256-color palette
    …
$ csl set bastille-day      # live within ~1s
```

## Install

```bash
git clone https://github.com/JaeggerJose/claude-statusline ~/.claude/statusline
cd ~/.claude/statusline && ./install.sh      # symlinks bin/csl → ~/.local/bin
```

Requires `jq`. Art themes also want `chafa` + `python3`+`PIL` and a truecolor
terminal with a "Symbols for Legacy Computing" font (Cascadia/Iosevka/JuliaMono).
Check everything with `csl doctor`.

Point Claude Code at the engine (once) in `~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command",
    "command": "bash ~/.claude/statusline/run.sh maplestory", "refreshInterval": 1 } }
```

…or just run `csl set <theme>` and it writes that for you.

## The CLI (`csl`) — package-manager verbs

| Command | What it does |
|---------|--------------|
| `csl list` | installed themes (`*` = active, with version) |
| `csl search [q]` | search themes by name/description |
| `csl info <name>` | manifest (version, render mode, deps) + build state |
| `csl doctor [name]` | check deps/capabilities (bin, python, truecolor) |
| `csl build <name>` | (re)run a theme's art recipe (`manifest.art.build`) |
| `csl set <name>` / `use` | activate (rewrites settings.json, atomic + backup) |
| `csl next` | cycle to the next theme |
| `csl preview <name>` | render the line once, without switching |
| `csl current` / `status` | what's active |
| `csl init <name>` | scaffold a new theme (`.sh` + `.json` manifest) |
| `csl edit <name>` / `path` | open a theme / print the dir |

Testability: set `CSL_HOME` and `CSL_SETTINGS` to point at fixtures — the real
config is never touched (the test suite relies on this).

## What a theme is (the package model)

A theme = a **render contract** + an optional **manifest**:

- `themes/<name>.sh` — palette (`T_*`), `ART_MODE`, `SHOW_*` toggles. Sourced by
  `run.sh` at render time. (Required — this is what actually draws.)
- `themes/<name>.json` — manifest: `version`, `description`, `render.mode`,
  `requires` (deps), and an `art.build` **recipe** that regenerates the art.
  (Optional — themes without it still work; metadata falls back to `THEME_DESC`.)

Art **recipes** are committed; built **artifacts** (ANSI frames, playlists) are
generated and git-ignored — same principle as npm not tracking `node_modules`.
Example: the `bastille-day` recipe is `statusline-art/bastille/{make_bastille.py,build.sh}`;
`csl build bastille-day` runs it to (re)produce the frames + playlist.

See [`docs/`](docs/) for the architecture survey and the full package-manager
design (manifest schema, git-tap registry, lockfile, migration path).

## The theme contract (authoring)

A theme `.sh` only sets what it wants to change; `lib/render.sh` defaults the rest.

```sh
THEME_DESC="one-line description"          # fallback metadata for `csl list`
ART_MODE="gallery|frames|sixel|iterm|none" # header art source
ART_CELLS_H=18                             # newline padding for image modes
ART_PLAYLIST="..."                         # gallery-mode playlist path
# Palette — base ANSI (A_RED/A_GREEN/A_CYAN/BOLD/DIM/RESET) or "\033[38;5;NNNm".
T_USER= T_DIR= T_GIT= T_MODEL= T_STYLE= T_TIME=
T_BAR_LOW= T_BAR_MID= T_BAR_HIGH=          # context bar by fill level
SEP="${DIM}|${RESET}"
SHOW_GIT=1 SHOW_STYLE=1 SHOW_CTXBAR=1 SHOW_RATE=1 SHOW_TIME=1
```

## Repo layout

```
bin/csl              the CLI (package manager)
run.sh               theme engine (sourced by settings.json's command)
lib/render.sh        shared renderer + theme contract
themes/<name>.sh     render contract per theme
themes/<name>.json   manifest per theme
install.sh           symlink csl onto PATH
test/run.sh          dependency-free test suite (47 checks)
docs/                architecture survey + package-manager design
```

## Tests

```bash
bash test/run.sh        # 47 checks; exit 0 = all pass
```

Covers manifest validity & name/mode consistency, `list/info/search`, atomic
`set` against a fixture settings.json, renderer output, gallery playlist
integrity, and a guard that the real `settings.json` is never mutated.

## Notes / gotchas

- Target **bash 3.2** (macOS default) — no `mapfile`, no `${var^^}`.
- The info line is emitted with `printf '%b'` so a literal `%` in `42%` is never
  parsed as a format conversion.
- `csl set` validates the jq output before atomically replacing settings.json,
  and keeps a rolling backup at `settings.json.csl.bak`.
