#!/bin/bash
# Status line theme launcher:  run.sh <theme>
#
# settings.json → statusLine.command points here WITH the active theme as its
# argument, e.g.  "bash ~/.claude/statusline/run.sh nord".
# `csl set <name>` swaps that argument, so settings.json is the single source of
# truth for which theme is active (claude-swap style — no separate state file).
#
# This file is the engine; the themes/ files are data. To customize a look, edit
# themes/<name>.sh — never this file.

input=$(cat)

SL_DIR="$HOME/.claude/statusline"
DEFAULT_THEME="maplestory"

theme="${1:-$DEFAULT_THEME}"
theme_file="$SL_DIR/themes/$theme.sh"
[ -f "$theme_file" ] || theme_file="$SL_DIR/themes/$DEFAULT_THEME.sh"

# render.sh defines base ANSI + defaults; theme overrides after; render() reads
# final values at call time (shell dynamic scope).
# shellcheck source=/dev/null
source "$SL_DIR/lib/render.sh"
# shellcheck source=/dev/null
[ -f "$theme_file" ] && source "$theme_file"

render "$input"
exit 0
