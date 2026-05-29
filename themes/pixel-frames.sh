# Theme: pixel-frames — static/animated cached frames + warm palette.
# Uses the frames generated from ~/Downloads/pixel_art_large.png.
THEME_DESC="Cached pixel-art frames + warm palette"

ART_MODE="frames"
ART_CELLS_H=18
ART_SRC="$HOME/Downloads/pixel_art_large.png"

T_USER="${BOLD}\033[38;5;215m"   # warm orange
T_DIR="\033[38;5;180m"           # tan
T_GIT="\033[38;5;108m"           # sage green
T_MODEL="\033[38;5;223m"         # cream
T_STYLE="${DIM}"
T_TIME="${DIM}"
T_BAR_LOW="\033[38;5;108m"
T_BAR_MID="\033[38;5;215m"
T_BAR_HIGH="\033[38;5;167m"
SEP="\033[38;5;240m|${RESET}"

SHOW_GIT=1; SHOW_STYLE=1; SHOW_CTXBAR=1; SHOW_RATE=1; SHOW_TIME=1
