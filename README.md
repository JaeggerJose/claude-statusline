# Status line theme system (`csl`)

A small CLI that switches the Claude Code status line between full-bundle
**preset themes** (art mode + palette + segment toggles), claude-swap style:
switching rewrites `settings.json` → `statusLine.command` to launch the chosen
theme. No restart needed (`refreshInterval: 1` picks it up within ~1s).

## How it fits together

```
~/.claude/settings.json
   statusLine.command = "bash ~/.claude/statusline/run.sh <active-theme>"
                                          │   ← csl rewrites this line
                                          ▼
~/.claude/statusline/
├── run.sh                ← engine launcher: run.sh <theme>
├── lib/render.sh         ← shared renderer (art + segments), driven by vars
├── themes/<name>.sh      ← one preset per file (palette, ART_MODE, SHOW_*)
└── README.md             ← this file

~/.local/bin/csl          ← the controller CLI
```

**settings.json is the single source of truth** for the active theme (no
separate state file). `run.sh` sources `lib/render.sh` then the named theme,
then renders. `csl set <name>` swaps the theme argument inside
`statusLine.command` via `jq` (preserving `refreshInterval`/`padding`), backing
the file up to `settings.json.csl.bak` first.

## CLI

| Command | Does |
|---|---|
| `csl list` | list themes, `*` marks active (read from settings.json) |
| `csl current` | print active theme |
| `csl set <name>` | switch theme (rewrites settings.json, backed up) |
| `csl status` | active theme + the exact `statusLine.command` |
| `csl preview <name>` | render once with sample data, no switch |
| `csl next` | cycle to next theme alphabetically |
| `csl edit <name>` | open theme in `$EDITOR` |
| `csl new <name>` | scaffold a new theme from a template |
| `csl path` | print `~/.claude/statusline` |

## Built-in themes

| Theme | Look |
|---|---|
| `maplestory` | **default** — rotating MapleStory mob/NPC sprite gallery (synced via `statusline-art/sync-from-maple.sh`) + Catppuccin 16-color row (the original look, preserved 1:1) |
| `pixel-frames` | cached pixel-art frames from `~/Downloads/pixel_art_large.png` + warm palette |
| `nord` | no art, cool Nord 256-color palette, full segments |
| `minimal` | no art, lean line (dir + context + clock only), `·` separators |
| `blank` | scaffold from `csl new` — neutral defaults, edit it into your own |

## Authoring a theme

A theme file only sets the variables it wants to change; `lib/render.sh`
supplies defaults for everything else.

```sh
THEME_DESC="one-line description"          # shown in `csl list`

ART_MODE="gallery|frames|sixel|iterm|none" # header art source
ART_CELLS_H=18                             # newline padding for image modes
ART_PLAYLIST="..."                         # gallery mode playlist path

# Palette — base ANSI (A_RED/A_GREEN/A_CYAN/BOLD/DIM/RESET ...) or "\033[38;5;NNNm".
T_USER= T_DIR= T_GIT= T_MODEL= T_STYLE= T_TIME=
T_BAR_LOW= T_BAR_MID= T_BAR_HIGH=          # context bar by fill level
SEP="${DIM}|${RESET}"                      # separator glyph

SHOW_GIT=1 SHOW_STYLE=1 SHOW_CTXBAR=1 SHOW_RATE=1 SHOW_TIME=1
```

## Notes / gotchas

- Target **bash 3.2** (macOS default) — no `mapfile`, no `${var^^}`, etc.
- The final line is emitted with `printf '%b'` (not a dynamic format string) so a
  literal `%` in `42%` is never parsed as a conversion — fixes a latent
  truncation bug from the original script.
- `csl set` backs up settings.json to `settings.json.csl.bak` and validates the
  jq output before replacing the file (atomic temp + `mv`).
- Original pre-refactor statusline script: `~/.claude/statusline-command.sh.pre-csl.bak`
  (the live `statusline-command.sh` is now unused; `run.sh` is the engine).
```
