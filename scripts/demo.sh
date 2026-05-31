#!/bin/bash
# csl demo — a clean, recordable showcase of the CLI.
#
# Record a cast:
#   asciinema rec -c "bash scripts/demo.sh" csl-demo.cast
# Then turn it into a looping GIF (see scripts/record-demo.md).
#
# SAFE: every `csl set`/`next` here writes to an ISOLATED temp settings.json, so
# your real ~/.claude/settings.json and live status line are never touched.
set -u

# Drive the installed csl; fall back to the repo's bin if not on PATH.
command -v csl >/dev/null 2>&1 || PATH="$HOME/.local/bin:$PATH"
command -v csl >/dev/null 2>&1 || PATH="$(cd "$(dirname "$0")/.." && pwd)/bin:$PATH"

# Isolated settings so the demo never mutates the real status line.
_demo_dir="$(mktemp -d)"; export CSL_SETTINGS="$_demo_dir/settings.json"
printf '{}\n' > "$CSL_SETTINGS"
trap 'rm -rf "$_demo_dir"' EXIT

GRN=$'\033[1;32m'; DIM=$'\033[2m'; RST=$'\033[0m'
PRE="${PAUSE_PRE:-0.7}"; POST="${PAUSE_POST:-1.8}"

run() { printf '%s$%s %s\n' "$GRN" "$RST" "$*"; sleep "$PRE"; "$@"; sleep "$POST"; printf '\n'; }
say() { printf '%s%s%s\n\n' "$DIM" "$1" "$RST"; sleep "${2:-1.3}"; }

clear 2>/dev/null || true
say "# csl — a package manager for your Claude Code status line"
run csl list                     # browse themes (core vs user tiers)
run csl preview nord             # try a theme without switching
run csl preview minimal
run csl set nord                 # activate — rewrites settings.json (isolated here)
run csl next                     # one-keystroke cycle to the next theme
run csl doctor nord              # self-check the environment
say "# the money shot: an animated pixel-art theme ↓"
run csl preview maplestory       # gallery art renders inline
say "# make your own:  csl init <name> → edit palette/art → csl build"
say "# settings.json stays the single source of truth. that's it." 2
