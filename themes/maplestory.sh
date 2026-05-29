# Theme: maplestory  (DEFAULT — the original look)
# Rotating MapleStory mob/NPC sprite gallery (synced from the maple-colorscripts
# repo via ~/.claude/statusline-art/sync-from-maple.sh) + Catppuccin-Mocha-ish
# 16-color info row.
THEME_DESC="Rotating MapleStory sprite gallery + Catppuccin palette"

ART_MODE="gallery"
ART_CELLS_H=18
ART_PLAYLIST="$HOME/.claude/statusline-art/gallery/playlist"

# Palette — matches the original hardcoded ANSI exactly.
T_USER="${BOLD}${A_RED}"     # user: bold red
T_DIR="${A_YELLOW}"          # dir: peach/yellow
T_GIT="${A_GREEN}"           # git branch: green
T_MODEL="${A_CYAN}"          # model name: cyan
T_STYLE="${DIM}"             # output style: dim
T_TIME="${DIM}"              # clock: dim
T_BAR_LOW="${A_GREEN}"
T_BAR_MID="${A_YELLOW}"
T_BAR_HIGH="${A_RED}"
SEP="${DIM}|${RESET}"

SHOW_GIT=1; SHOW_STYLE=1; SHOW_CTXBAR=1; SHOW_RATE=1; SHOW_TIME=1
