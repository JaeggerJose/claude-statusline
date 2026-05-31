#!/bin/bash
# Two-tier theme resolution — shared by bin/csl and run.sh (single source of
# truth so the CLI and the engine never disagree about where a theme lives).
#
#   built-in tier : $CSL_REPO/themes        (ships with the tool; everyone has it)
#   user tier     : $CSL_USER_DIR           (personal + installed; per-machine)
#                   default ~/.config/csl/themes (XDG), override with CSL_USER_DIR
#
# The USER tier OVERRIDES the built-in tier by name — exactly like a VS Code user
# theme shadowing a bundled one. New themes (`csl init`) and installed themes
# land in the user tier; the tool repo stays content-free beyond a few universals.
#
# Callers should export CSL_REPO (the repo root) before sourcing; otherwise we
# self-locate from this file's directory.

: "${CSL_REPO:=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." >/dev/null 2>&1 && pwd)}"
CSL_BUILTIN_DIR="$CSL_REPO/themes"
CSL_USER_DIR="${CSL_USER_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/csl/themes}"

# csl_valid_name <name> → 0 if a safe theme name. Rejects empty, anything with a
# char outside [A-Za-z0-9._-], and any leading dot (kills `.`/`..`/hidden and
# thus path traversal). This is the security gate: the engine sources a theme's
# .sh every refresh, so a name must never escape the theme dirs or carry shell
# metacharacters that could land in settings.json's statusLine.command.
csl_valid_name() {
  case "$1" in
    ''|.*|*[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

# csl_theme_sh <name> → path to the .sh (user tier wins); empty if invalid/not found.
csl_theme_sh() {
  csl_valid_name "$1" || return 1
  if   [ -f "$CSL_USER_DIR/$1.sh" ];    then printf '%s' "$CSL_USER_DIR/$1.sh"
  elif [ -f "$CSL_BUILTIN_DIR/$1.sh" ]; then printf '%s' "$CSL_BUILTIN_DIR/$1.sh"
  fi
}

# csl_theme_json <name> → path to the manifest (user tier wins); empty if invalid/none.
csl_theme_json() {
  csl_valid_name "$1" || return 1
  if   [ -f "$CSL_USER_DIR/$1.json" ];    then printf '%s' "$CSL_USER_DIR/$1.json"
  elif [ -f "$CSL_BUILTIN_DIR/$1.json" ]; then printf '%s' "$CSL_BUILTIN_DIR/$1.json"
  fi
}

# csl_theme_origin <name> → "user" | "built-in" | "" (not found).
csl_theme_origin() {
  if   [ -f "$CSL_USER_DIR/$1.sh" ];    then printf 'user'
  elif [ -f "$CSL_BUILTIN_DIR/$1.sh" ]; then printf 'built-in'
  fi
}

# csl_theme_names → unique theme names across both tiers, sorted.
csl_theme_names() {
  local d f
  { for d in "$CSL_USER_DIR" "$CSL_BUILTIN_DIR"; do
      [ -d "$d" ] || continue
      for f in "$d"/*.sh; do [ -e "$f" ] && basename "$f" .sh; done
    done; } | sort -u
}
