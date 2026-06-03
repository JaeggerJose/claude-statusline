#!/bin/bash
# Status line COMPONENTS — the building blocks of the component composer.
#
# A theme opts into the composer by declaring CSL_ROWS (see render.sh
# _csl_compose). Each row is a space-separated list of component NAMES; for each
# name the composer runs `comp_<name> "$input" "$columns"` and joins the
# non-empty results with CSL_SEP.
#
# Component contract:
#   comp_<name> "$input" "$columns"
#     - $1 = the raw Claude statusLine JSON (same stdin run.sh received)
#     - $2 = a per-row column budget (default 80; honoured by board components)
#     - ECHOES the rendered segment with ANSI escapes as LITERAL backslash
#       sequences (\033...), so the composer's `printf '%b'` expands them.
#     - ECHOES NOTHING when the segment is N/A (composer omits it).
#     - NO global mutation. NEVER errors out (always `|| true`-safe).
#
# Visuals/colours are ported VERBATIM from render_classic() so a composed line
# matches the classic look cell-for-cell. Components reuse the T_* palette vars,
# SEP, BOLD/DIM/RESET and the SHOW_* toggles already defined in render.sh.

# --- helpers ----------------------------------------------------------------
# Read a single field from the input JSON; empty string on any failure.
_csl_jq() {
  echo "$1" | jq -r "$2" 2>/dev/null || true
}

# Resolve the cwd the classic renderer uses (workspace.current_dir → .cwd → "").
_csl_cwd() { _csl_jq "$1" '.workspace.current_dir // .cwd // ""'; }

# --- comp_user --------------------------------------------------------------
# "<user>" in T_USER. Mirrors classic seg_user (no surrounding "in").
comp_user() {
  local user; user=$(whoami)
  printf '%s' "${T_USER}${user}${RESET}"
}

# --- comp_dir ---------------------------------------------------------------
# Shortened cwd in T_DIR. Mirrors classic short_dir logic verbatim.
comp_dir() {
  local cwd short_dir component_count
  cwd=$(_csl_cwd "$1")
  if [ -n "$cwd" ]; then
    short_dir="${cwd/#$HOME/~}"
    component_count=$(echo "$short_dir" | tr -cd '/' | wc -c | tr -d ' ')
    if [ "$component_count" -gt 3 ]; then
      short_dir="…/$(echo "$short_dir" | rev | cut -d'/' -f1-3 | rev)"
    fi
  else
    short_dir=$(pwd | sed "s|$HOME|~|")
  fi
  printf '%s' "${T_DIR}${short_dir}${RESET}"
}

# --- comp_git ---------------------------------------------------------------
# " on  <branch>" when inside a work tree (honours SHOW_GIT). Mirrors classic
# seg_git exactly, including the leading space the classic line embeds.
comp_git() {
  local cwd git_branch
  cwd=$(_csl_cwd "$1")
  git_branch=""
  if [ "${SHOW_GIT:-1}" = "1" ] && \
     git -C "${cwd:-$PWD}" --no-optional-locks rev-parse --is-inside-work-tree 2>/dev/null | grep -q true; then
    git_branch=$(git -C "${cwd:-$PWD}" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  fi
  [ -n "$git_branch" ] || return 0
  printf '%s' " ${T_DIM}on${RESET} ${T_GIT} ${git_branch}${RESET}"
}

# --- comp_model -------------------------------------------------------------
# Model display name in T_MODEL (no bar). Mirrors classic ctx_label else-branch.
comp_model() {
  local model
  model=$(_csl_jq "$1" '.model.display_name // "Unknown"')
  printf '%s' "${T_MODEL}${model}${RESET}"
}

# --- comp_ctx ---------------------------------------------------------------
# Model name + 10-block context bar + percent. Mirrors classic ctx_label
# (SHOW_CTXBAR branch) verbatim. Falls back to bare model when no pct / disabled.
comp_ctx() {
  # Context fill ONLY: a 10-block bar + percent. The model name is comp_model's
  # job (keep components orthogonal so 'model ctx' doesn't print the name twice).
  local used_pct
  used_pct=$(_csl_jq "$1" '.context_window.used_percentage // empty')
  [ -n "$used_pct" ] || return 0   # no context window => component disappears
  local ctx_int filled empty bar bar_color i
  ctx_int=$(printf "%.0f" "$used_pct")
  [ "$ctx_int" -lt 0 ]   && ctx_int=0
  [ "$ctx_int" -gt 100 ] && ctx_int=100
  filled=$(( ctx_int / 10 )); empty=$(( 10 - filled )); bar=""
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty;  i++)); do bar="${bar}░"; done
  if   [ "$ctx_int" -ge 90 ]; then bar_color="${T_BAR_HIGH}"
  elif [ "$ctx_int" -ge 70 ]; then bar_color="${T_BAR_MID}"
  else                              bar_color="${T_BAR_LOW}"; fi
  printf "%s%s%s %d%%" "${bar_color}" "${bar}" "${RESET}" "${ctx_int}"
}

# --- comp_tokens ------------------------------------------------------------
# "5h:NN% 7d:NN%" rate gauges in T_DIM (honours SHOW_RATE). Mirrors classic
# rate_seg verbatim, including the leading space before each gauge.
comp_tokens() {
  local five_pct week_pct rate_seg
  five_pct=$(_csl_jq "$1" '.rate_limits.five_hour.used_percentage // empty')
  week_pct=$(_csl_jq "$1" '.rate_limits.seven_day.used_percentage // empty')
  rate_seg=""
  if [ "${SHOW_RATE:-1}" = "1" ]; then
    [ -n "$five_pct" ] && rate_seg=$(printf " 5h:%.0f%%" "$five_pct")
    [ -n "$week_pct" ] && rate_seg="${rate_seg}$(printf " 7d:%.0f%%" "$week_pct")"
    [ -n "$rate_seg" ] && rate_seg="${T_DIM}${rate_seg}${RESET}"
  fi
  [ -n "$rate_seg" ] || return 0
  printf '%s' "$rate_seg"
}

# --- comp_style -------------------------------------------------------------
# Output-style name in T_STYLE (honours SHOW_STYLE). Mirrors classic seg_style
# WITHOUT the leading " ${SEP} " (the composer's CSL_SEP supplies separators).
comp_style() {
  local style
  [ "${SHOW_STYLE:-1}" = "1" ] || return 0
  style=$(_csl_jq "$1" '.output_style.name // "default"')
  printf '%s' "${T_STYLE}${style}${RESET}"
}

# --- comp_clock -------------------------------------------------------------
# HH:MM in T_TIME (honours SHOW_TIME). Mirrors classic seg_time WITHOUT the
# leading " ${SEP} " (the composer's CSL_SEP supplies separators).
comp_clock() {
  local now
  [ "${SHOW_TIME:-1}" = "1" ] || return 0
  now=$(date +%H:%M)
  printf '%s' "${T_TIME}${now}${RESET}"
}

# --- comp_jrboard -----------------------------------------------------------
# One-line JR departure board (pure transit, no token gauges). Reads the same
# Claude JSON from stdin and honours the column budget. Echoes nothing on
# failure so the composer omits the row rather than printing an error.
comp_jrboard() {
  # Pure transit board (no token gauge — that's comp_tokens). Opt-in env:
  #   JR_BY_SESSION=1  pick a different line per Claude session
  #   JR_CITY=Tokyo    scope auto-selection to a city
  #   JR_LINE/JR_STATION  pin a specific line/station (overrides by-session)
  local input="$1" cols="${2:-80}" out
  out=$(printf '%s' "$input" | python3 -m jrboard \
          --mode statusline --claude-stdin \
          ${JR_BY_SESSION:+--by-session} \
          ${JR_CITY:+--city "$JR_CITY"} \
          ${JR_LINE:+--line "$JR_LINE"} ${JR_STATION:+--station "$JR_STATION"} \
          --columns "$cols" 2>/dev/null) || true
  [ -n "$out" ] || return 0
  printf '%s' "$out"
}

# --- comp_jrtable -----------------------------------------------------------
# Multi-line JR mini-table (its own newlines pass through the composer). Reads
# the same Claude JSON from stdin and honours the column budget.
comp_jrtable() {
  # Multi-line mini-table board. Honours the same JR_* opt-ins as comp_jrboard.
  local input="$1" cols="${2:-80}" out
  out=$(printf '%s' "$input" | python3 -m jrboard \
          --mode minitable --claude-stdin \
          ${JR_BY_SESSION:+--by-session} \
          ${JR_CITY:+--city "$JR_CITY"} \
          ${JR_LINE:+--line "$JR_LINE"} ${JR_STATION:+--station "$JR_STATION"} \
          --columns "$cols" 2>/dev/null) || true
  [ -n "$out" ] || return 0
  printf '%s' "$out"
}
