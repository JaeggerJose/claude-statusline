#!/bin/bash
# Shared status line renderer.
#
# This is sourced by ~/.claude/statusline-command.sh AFTER a theme file has been
# sourced. The theme file sets a handful of variables (palette, art mode, segment
# toggles); everything here reads those variables and falls back to sensible
# defaults, so a theme only declares what it wants to change.
#
# Contract a theme MAY set (all optional — defaults below):
#   ART_MODE        gallery | frames | sixel | iterm | none   (default: none)
#   ART_CELLS_H     image cell-height / newline padding         (default: 18)
#   ART_PLAYLIST    playlist file for gallery mode               (default: $ART_DIR/gallery/playlist)
#   ART_SRC         source PNG for frames/iterm regeneration     (default: ~/Downloads/pixel_art_large.png)
#   Palette (raw ANSI escapes):
#     T_USER T_DIR T_GIT T_MODEL T_STYLE T_TIME T_DIM
#     T_BAR_LOW T_BAR_MID T_BAR_HIGH   (context bar by fill level)
#   SEP             separator glyph, already styled              (default: dim "|")
#   Toggles (1/0):  SHOW_GIT SHOW_STYLE SHOW_CTXBAR SHOW_RATE SHOW_TIME
#
# render() takes the raw stdin JSON as $1 and prints the full status line.

# ---- Base ANSI (themes reference these for their palette) ----
RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
A_RED="\033[31m"; A_GREEN="\033[32m"; A_YELLOW="\033[33m"
A_BLUE="\033[34m"; A_MAGENTA="\033[35m"; A_CYAN="\033[36m"; A_WHITE="\033[37m"

# ---- Defaults (overridable by the sourced theme) ----
: "${ART_MODE:=none}"
: "${ART_CELLS_H:=18}"
: "${ART_DIR:=$HOME/.claude/statusline-art}"
: "${ART_GEN:=$HOME/.claude/statusline-gen-art.sh}"
: "${ART_SRC:=$HOME/Downloads/pixel_art_large.png}"
: "${ART_PLAYLIST:=$ART_DIR/gallery/playlist}"

: "${T_USER:=${BOLD}${A_RED}}"
: "${T_DIR:=${A_YELLOW}}"
: "${T_GIT:=${A_GREEN}}"
: "${T_MODEL:=${A_CYAN}}"
: "${T_STYLE:=${DIM}}"
: "${T_TIME:=${DIM}}"
: "${T_DIM:=${DIM}}"
: "${T_BAR_LOW:=${A_GREEN}}"
: "${T_BAR_MID:=${A_YELLOW}}"
: "${T_BAR_HIGH:=${A_RED}}"
: "${SEP:=${DIM}|${RESET}}"

: "${SHOW_GIT:=1}"
: "${SHOW_STYLE:=1}"
: "${SHOW_CTXBAR:=1}"
: "${SHOW_RATE:=1}"
: "${SHOW_TIME:=1}"

# ---- Header art ----------------------------------------------------------
# Emits the image/animation block for the current ART_MODE. Pure side-effect
# (prints to stdout). Logic preserved from the original statusline-command.sh.
render_art() {
  case "$ART_MODE" in
    gallery)
      if [ -s "$ART_PLAYLIST" ]; then
        local total idx frame_file
        total=$(wc -l <"$ART_PLAYLIST" | tr -d ' ')
        if [ "${total:-0}" -gt 0 ]; then
          idx=$(( $(date +%s) % total ))
          frame_file=$(sed -n "$((idx + 1))p" "$ART_PLAYLIST")
          [ -s "$frame_file" ] && cat "$frame_file"
        fi
      fi
      ;;
    sixel)
      local sixel="$ART_DIR/sixel.txt"
      if [ -s "$sixel" ]; then
        cat "$sixel"
        for _ in $(seq 1 "$ART_CELLS_H"); do printf '\n'; done
      fi
      ;;
    iterm)
      local iterm="$ART_DIR/iterm.txt" bytes
      if [ -f "$ART_SRC" ] && { [ ! -s "$iterm" ] || [ "$ART_SRC" -nt "$iterm" ]; }; then
        mkdir -p "$ART_DIR"
        bytes=$(wc -c <"$ART_SRC" | tr -d ' ')
        { printf '\033]1337;File=inline=1;width=44;height=%s;preserveAspectRatio=0;size=%s:' "$ART_CELLS_H" "$bytes"
          base64 <"$ART_SRC" | tr -d '\n'
          printf '\007'
        } >"$iterm" 2>/dev/null || true
      fi
      if [ -s "$iterm" ]; then
        cat "$iterm"
        for _ in $(seq 1 "$ART_CELLS_H"); do printf '\n'; done
      fi
      ;;
    frames)
      if [ -f "$ART_SRC" ] && { [ ! -f "$ART_DIR/.src" ] || [ "$ART_SRC" -nt "$ART_DIR/.src" ]; }; then
        bash "$ART_GEN" "$ART_SRC" "$ART_DIR" 48x48 >/dev/null 2>&1 || true
      fi
      if [ -f "$ART_DIR/count" ]; then
        local frame_count idx frame_file
        frame_count=$(tr -cd '0-9' < "$ART_DIR/count" 2>/dev/null)
        if [ "${frame_count:-0}" -gt 0 ]; then
          idx=$(( $(date +%s) % frame_count ))
          frame_file=$(printf '%s/frame%03d.txt' "$ART_DIR" "$idx")
          [ -s "$frame_file" ] && cat "$frame_file"
        fi
      fi
      ;;
    none|*) : ;;  # no header art
  esac
}

# ---- Full line -----------------------------------------------------------
render() {
  local input="$1"

  render_art

  # --- Claude Code data ---
  local cwd model style used_pct five_pct week_pct
  cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
  model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
  style=$(echo "$input" | jq -r '.output_style.name // "default"')
  used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

  # --- Shell-derived data ---
  local user short_dir component_count git_branch now
  user=$(whoami)
  if [ -n "$cwd" ]; then
    short_dir="${cwd/#$HOME/~}"
    component_count=$(echo "$short_dir" | tr -cd '/' | wc -c | tr -d ' ')
    if [ "$component_count" -gt 3 ]; then
      short_dir="…/$(echo "$short_dir" | rev | cut -d'/' -f1-3 | rev)"
    fi
  else
    short_dir=$(pwd | sed "s|$HOME|~|")
  fi

  git_branch=""
  if [ "$SHOW_GIT" = "1" ] && \
     git -C "${cwd:-$PWD}" --no-optional-locks rev-parse --is-inside-work-tree 2>/dev/null | grep -q true; then
    git_branch=$(git -C "${cwd:-$PWD}" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  fi

  now=$(date +%H:%M)

  # --- Segments ---
  local seg_user seg_dir seg_git seg_style ctx_label rate_seg seg_time
  seg_user="${T_USER}${user}${RESET}"
  seg_dir="${T_DIR}${short_dir}${RESET}"

  seg_git=""
  [ -n "$git_branch" ] && seg_git=" ${T_DIM}on${RESET} ${T_GIT} ${git_branch}${RESET}"

  seg_style=""
  [ "$SHOW_STYLE" = "1" ] && seg_style=" ${SEP} ${T_STYLE}${style}${RESET}"

  # Context: model name + (optional) 10-block bar + percent
  if [ "$SHOW_CTXBAR" = "1" ] && [ -n "$used_pct" ]; then
    local ctx_int filled empty bar bar_color i
    ctx_int=$(printf "%.0f" "$used_pct")
    # Clamp to 0..100 so the bar is always exactly 10 cells: a negative or >100
    # value would make `empty` negative and (with the old `seq 1 N`) flood the
    # bar; C-style loops also avoid BSD `seq 1 0` emitting "1 0" (two iterations).
    [ "$ctx_int" -lt 0 ]   && ctx_int=0
    [ "$ctx_int" -gt 100 ] && ctx_int=100
    filled=$(( ctx_int / 10 )); empty=$(( 10 - filled )); bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty;  i++)); do bar="${bar}░"; done
    if   [ "$ctx_int" -ge 90 ]; then bar_color="${T_BAR_HIGH}"
    elif [ "$ctx_int" -ge 70 ]; then bar_color="${T_BAR_MID}"
    else                              bar_color="${T_BAR_LOW}"; fi
    ctx_label=$(printf "%s %s%s%s %d%%" "${T_MODEL}${model}${RESET}" "${bar_color}" "${bar}" "${RESET}" "${ctx_int}")
  else
    ctx_label="${T_MODEL}${model}${RESET}"
  fi

  rate_seg=""
  if [ "$SHOW_RATE" = "1" ]; then
    [ -n "$five_pct" ] && rate_seg=$(printf " 5h:%.0f%%" "$five_pct")
    [ -n "$week_pct" ] && rate_seg="${rate_seg}$(printf " 7d:%.0f%%" "$week_pct")"
    [ -n "$rate_seg" ] && rate_seg="${T_DIM}${rate_seg}${RESET}"
  fi

  seg_time=""
  [ "$SHOW_TIME" = "1" ] && seg_time=" ${SEP} ${T_TIME}${now}${RESET}"

  # --- Compose ---
  # Build the full line in a var, then `printf '%b'`. %b expands backslash
  # escapes (the \033 color codes) but treats literal % (e.g. "42%") as data —
  # avoiding the old bug where a "%" in ctx_label was parsed as a printf
  # conversion and silently truncated the rest of the line.
  local line="${seg_user} ${T_DIM}in${RESET} ${seg_dir}${seg_git}${seg_style} ${SEP} ${ctx_label}${rate_seg}${seg_time}"
  printf '%b' "$line" 2>/dev/null || true
}
