# Status-Line System — Architecture Survey (current state)

> Snapshot of how the Claude Code status-line theming system works **today**,
> surveyed 2026-05-29. This is the "as-is" map that the package-manager design
> ([01-package-manager-design.md](01-package-manager-design.md)) builds on.

## 1. Data flow (one status-line refresh)

```
Claude Code (refreshInterval=1s)
   │  pipes session JSON on stdin
   ▼
settings.json → statusLine.command
   = "bash ~/.claude/statusline/run.sh <active-theme>"
   ▼
run.sh
   1. reads stdin JSON
   2. source lib/render.sh         (base ANSI vars + defaults + render())
   3. source themes/<theme>.sh     (overrides: palette, ART_MODE, SHOW_*)
   4. render "$json"
   ▼
render() → render_art() prints header art, then composes the info line
   ▼
stdout → Claude Code draws it
```

**Single source of truth for the active theme = `settings.json`** (claude-swap
style). There is no separate state file; the theme name is the last token of
`statusLine.command`.

## 2. Key files

| File | Role |
|------|------|
| `~/.claude/settings.json` | `statusLine.command` points at `run.sh <theme>`; the active-theme SoT |
| `~/.claude/statusline/run.sh` | Engine. Sources render.sh + the theme, calls `render()` |
| `~/.claude/statusline/lib/render.sh` | Shared renderer: ANSI vars, `render_art()`, `render()` |
| `~/.claude/statusline/themes/<name>.sh` | Theme data: palette (`T_*`), `ART_MODE`, `SHOW_*` toggles |
| `~/.local/bin/csl` | CLI: list/set/preview/next/status/edit/new/path. `set` rewrites settings.json (jq, atomic, backup) |
| `~/.claude/statusline-gen-art.sh` | Image/GIF → ANSI frames via `chafa`; PIL splits GIF frames; U+2800 padding |
| `~/.claude/statusline-art/` | Built art assets (frames, gallery, playlists) |
| `~/.claude/statusline-art/sync-from-maple.sh` | Pulls MapleStory sprites from maple-colorscripts repo → gallery playlist |

## 3. The theme contract (what a `theme.sh` may set)

All optional; `render.sh` supplies defaults.

- **Art:** `ART_MODE` = `gallery | frames | sixel | iterm | none`; `ART_CELLS_H`;
  `ART_PLAYLIST` (gallery); `ART_SRC` (frames/iterm regeneration source).
- **Palette (raw ANSI):** `T_USER T_DIR T_GIT T_MODEL T_STYLE T_TIME T_DIM`,
  context bar `T_BAR_LOW/MID/HIGH`, separator `SEP`.
- **Toggles (1/0):** `SHOW_GIT SHOW_STYLE SHOW_CTXBAR SHOW_RATE SHOW_TIME`.
- **Metadata:** `THEME_DESC="..."` (csl greps this for `list`).

## 4. The four ART_MODEs

| Mode | How it renders | Used by |
|------|----------------|---------|
| `gallery` | Cycles a **playlist** file (`idx = epoch % total`), `cat`s the frame | maplestory, pokemon-gallery, bastille-day |
| `frames` | Auto-regens frames from `ART_SRC` (hardcoded `48x48`) when source is newer, then cycles by `epoch % count` | pixel-frames |
| `sixel` | `cat`s `sixel.txt` + N blank lines | — |
| `iterm` | Emits an iTerm2 inline-image escape from `ART_SRC` | — |
| `none` | No header art | minimal, nord, blank |

**Insight:** `gallery` is the most controllable for bespoke art — you own the
frames and the playlist, no hardcoded size. That's why the bastille pack uses it.

## 5. The art pipeline (how pixels become a status line)

```
source image/GIF
   ▼  statusline-gen-art.sh
PIL splits frames → chafa --format symbols --colors full --symbols sextant
   ▼  sed strips cursor codes; perl maps space → U+2800 (survives CC trim)
frameNNN.txt  (truecolor ANSI, sextant sub-cell blocks)
   ▼  (gallery) a playlist lists frames, optionally repeated for pacing
render_art() cats one frame per refresh
```

- **chafa is a downsampler:** draw the source large with flat fills + high local
  contrast; detail below ~2px is lost to the 2×3 sextant cell.
- **U+2800 (Braille blank)** replaces spaces because Claude Code trims leading
  whitespace per line, which would otherwise shear the art.
- **Truecolor + a legacy-computing-symbols font** (Cascadia/Iosevka/JuliaMono)
  is required for crisp output.

## 6. The two art-production lineages (today)

1. **MapleStory (external API):** `maple-colorscripts` repo `mobs.list` →
   `sync-from-maple.sh` fetches sprite GIFs from maplestory.io → gen-art →
   `gallery/<id>/frame*.txt` → flat `gallery/playlist`.
2. **Bastille Day (hand-authored):** `statusline-art/bastille/make_bastille.py`
   (PIL) draws an 18-frame dusk-fireworks postcard → `bastille.gif` → gen-art
   `48x24` → `bastille/frame*.txt` + a playlist.

Both end in the same place: a **playlist of ANSI frames** the gallery mode cycles.
This convergence is exactly why a generic "art.build recipe" abstraction fits.

## 7. Gaps that motivate the package-manager design

- Theme metadata lives in `.sh` comments (grep'd), not a structured manifest.
- No notion of where a theme **came from** (no registry/source/version).
- Art recipe (generator) and artifact (frames) are not formally linked, so
  "rebuild this theme's art" is a manual, per-theme incantation.
- No dependency/capability check (chafa? python+PIL? truecolor?) before use.
- No install/remove/upgrade/share lifecycle — only local hand-editing.

→ See [01-package-manager-design.md](01-package-manager-design.md).
