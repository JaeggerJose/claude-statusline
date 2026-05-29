# Theme: bastille-day — 14 juillet pixel-art header + tricolore palette.
# A dusk-fireworks Paris postcard (Eiffel Tower, tricolore flag, fleur-de-lis,
# Provence lavender, Bordeaux oysters + wine, Patrouille de France trails,
# revolutionary cockade) animated over 18 frames, cycled 1 fps.
#
# Art lives in ~/.claude/statusline-art/bastille (regenerate with:
#   python3 ~/.claude/statusline-art/bastille/make_bastille.py
#   ART_SYMBOLS=block+border+space+sextant ART_EXTRACTOR=median \
#     bash ~/.claude/statusline-gen-art.sh \
#       ~/.claude/statusline-art/bastille/bastille.gif \
#       ~/.claude/statusline-art/bastille 48x24
#   then rebuild the playlist — see that dir's README).
THEME_DESC="14 juillet — Bastille Day fireworks + tricolore palette"

ART_MODE="gallery"
ART_CELLS_H=18
ART_PLAYLIST="$HOME/.claude/statusline-art/bastille/playlist"

# Tricolore palette (24-bit; brightened from the flag's official hues so the
# blue/red stay legible on a dark terminal).
T_USER="${BOLD}\033[38;2;72;142;230m"    # bleu — bold French blue
T_DIR="\033[38;2;240;240;245m"           # blanc — cream/white path
T_GIT="\033[38;2;239;88;76m"             # rouge — French red
T_MODEL="\033[38;2;232;200;120m"         # gold — Eiffel night lights
T_STYLE="${DIM}"
T_TIME="\033[38;2;200;160;120m"          # dusk amber
T_BAR_LOW="\033[38;2;72;142;230m"        # blue   (low fill)
T_BAR_MID="\033[38;2;232;200;120m"       # gold   (mid fill)
T_BAR_HIGH="\033[38;2;239;88;76m"        # red    (high fill)
SEP="\033[38;2;232;200;120m❖${RESET}"    # gold fleur-ish separator

SHOW_GIT=1; SHOW_STYLE=1; SHOW_CTXBAR=1; SHOW_RATE=1; SHOW_TIME=1
