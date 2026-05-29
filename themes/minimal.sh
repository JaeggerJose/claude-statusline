# Theme: minimal — no header art, lean single line, low chroma.
THEME_DESC="No art, lean single-line, low chroma"

ART_MODE="none"

T_USER="${BOLD}${A_WHITE}"
T_DIR="${A_CYAN}"
T_GIT="${DIM}"
T_MODEL="${A_WHITE}"
T_STYLE="${DIM}"
T_TIME="${DIM}"
T_BAR_LOW="${DIM}"
T_BAR_MID="${A_YELLOW}"
T_BAR_HIGH="${A_RED}"
SEP="${DIM}·${RESET}"

# Trim noise: keep dir + context + clock, drop git/style/rate.
SHOW_GIT=0; SHOW_STYLE=0; SHOW_CTXBAR=1; SHOW_RATE=0; SHOW_TIME=1
