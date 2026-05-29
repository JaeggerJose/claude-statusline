#!/bin/bash
# csl test suite — dependency-free (no bats). TAP-ish output.
#
# Safety: every test that mutates settings.json points CSL_SETTINGS at a temp
# fixture, so the real ~/.claude/settings.json is never touched. A guard test
# asserts the real file's hash is unchanged across the whole run.
#
# Usage:  bash test/run.sh        (exit 0 = all pass, 1 = failures)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CSL="$REPO/bin/csl"
THEMES="$REPO/themes"
RENDER="$REPO/lib/render.sh"
REAL_SETTINGS="$HOME/.claude/settings.json"

# Isolated fixture settings.json (csl writes here, not the real one).
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/settings.json"
printf '{"statusLine":{"type":"command","command":"bash %s/run.sh maplestory","refreshInterval":1}}\n' "$REPO" > "$FIX"

# csl invoked against the repo + fixture settings.
csl() { CSL_HOME="$REPO" CSL_SETTINGS="$FIX" CSL_GEN="$HOME/.claude/statusline-gen-art.sh" bash "$CSL" "$@"; }

# --- tiny assertion harness ----------------------------------------------
PASS=0; FAIL=0; N=0
ok()   { N=$((N+1)); PASS=$((PASS+1)); printf 'ok %d - %s\n' "$N" "$1"; }
no()   { N=$((N+1)); FAIL=$((FAIL+1)); printf 'not ok %d - %s\n' "$N" "$1"; [ -n "${2:-}" ] && printf '  # %s\n' "$2"; }
assert_eq()       { [ "$2" = "$3" ] && ok "$1" || no "$1" "expected [$3] got [$2]"; }
assert_contains() { case "$2" in *"$3"*) ok "$1";; *) no "$1" "[$2] does not contain [$3]";; esac; }
assert_ok()       { if "$@" >/dev/null 2>&1; then ok "exit 0: $*"; else no "exit 0: $*" "exit $?"; fi; }
assert_fail()     { if "$@" >/dev/null 2>&1; then no "nonzero: $*" "expected failure"; else ok "nonzero: $*"; fi; }

real_hash_before=$(shasum "$REAL_SETTINGS" 2>/dev/null | awk '{print $1}')

echo "# csl test suite (repo=$REPO)"

# 1. help / unknown command
assert_ok   csl help
assert_fail csl this-is-not-a-command

# 2. list shows every theme that has a .sh
sh_count=$(ls "$THEMES"/*.sh 2>/dev/null | wc -l | tr -d ' ')
list_count=$(csl list | grep -cE '^\s*\*?\s*\x1b\[3' || true)
# count lines that look like theme rows (start with optional * then a colored name)
list_rows=$(csl list | sed '1d' | grep -c . || true)
assert_eq "list shows all $sh_count themes" "$list_rows" "$sh_count"

# 3. every manifest is valid JSON with required fields, name matches filename,
#    and render.mode is one of the known modes.
modes="gallery frames sixel iterm none"
for js in "$THEMES"/*.json; do
  base=$(basename "$js" .json)
  if jq empty "$js" >/dev/null 2>&1; then ok "valid JSON: $base.json"; else no "valid JSON: $base.json"; continue; fi
  assert_eq "$base.json .name matches file" "$(jq -r '.name' "$js")" "$base"
  v=$(jq -r '.version' "$js");      [ "$v" != "null" ] && ok "$base has version" || no "$base has version"
  m=$(jq -r '.render.mode' "$js")
  case " $modes " in *" $m "*) ok "$base render.mode '$m' valid";; *) no "$base render.mode '$m' valid";; esac
done

# 4. manifest render.mode is consistent with the .sh ART_MODE (when the .sh sets one)
for js in "$THEMES"/*.json; do
  base=$(basename "$js" .json); sh="$THEMES/$base.sh"
  [ -f "$sh" ] || continue
  shmode=$(sed -n 's/^ART_MODE="\([a-z]*\)".*/\1/p' "$sh" | head -1)
  [ -z "$shmode" ] && shmode="none"   # default when unset
  jsmode=$(jq -r '.render.mode' "$js")
  assert_eq "$base: manifest mode == .sh ART_MODE" "$jsmode" "$shmode"
done

# 5. info prints version + build state
assert_contains "info bastille-day shows version" "$(csl info bastille-day)" "1.0.0"

# 6. search matches by description
assert_contains "search 'oyster' finds bastille-day" "$(csl search oyster)" "bastille-day"
assert_contains "search 'maple' finds maplestory"     "$(csl search maple)"  "maplestory"

# 7. set rewrites the FIXTURE settings.json (not the real one)
csl set nord >/dev/null 2>&1
newcmd=$(jq -r '.statusLine.command' "$FIX")
assert_contains "set nord rewrites command" "$newcmd" "run.sh nord"
assert_eq       "current reflects set"      "$(csl current | tr -d '\n')" "nord"

# 8. set is atomic + keeps it valid JSON; refreshInterval preserved
assert_ok jq empty "$FIX"
assert_eq "refreshInterval preserved" "$(jq -r '.statusLine.refreshInterval' "$FIX")" "1"

# 9. set unknown theme fails and does not corrupt settings
csl set nonexistent-theme >/dev/null 2>&1 || true
assert_eq "unknown set leaves nord active" "$(csl current | tr -d '\n')" "nord"

# 10. doctor: no-deps theme passes; reports green
assert_ok csl doctor nord

# 11. renderer produces an info row containing the model + cwd
sample='{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"/tmp/demo"},"output_style":{"name":"explanatory"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":18},"seven_day":{"used_percentage":63}}}'
out=$( source "$RENDER"; source "$THEMES/minimal.sh"; render "$sample" )
assert_contains "render shows model name"   "$out" "Opus 4.8"
assert_contains "render shows context %"    "$out" "42%"

# 12. gallery integrity: if a gallery theme is built, every playlist path exists
for js in "$THEMES"/*.json; do
  base=$(basename "$js" .json)
  [ "$(jq -r '.render.mode' "$js")" = "gallery" ] || continue
  dir=$(jq -r '.art.dir // empty' "$js"); dir="${dir/#\~/$HOME}"
  pl="$dir/playlist"
  [ -s "$pl" ] || { ok "$base playlist not built (skip integrity)"; continue; }
  missing=0
  while IFS= read -r fp; do [ -s "$fp" ] || missing=$((missing+1)); done < "$pl"
  assert_eq "$base playlist: all frames exist" "$missing" "0"
done

# 13. GUARD: the real settings.json was never touched
real_hash_after=$(shasum "$REAL_SETTINGS" 2>/dev/null | awk '{print $1}')
assert_eq "real settings.json untouched" "$real_hash_after" "$real_hash_before"

# --- summary --------------------------------------------------------------
echo "1..$N"
printf '# pass %d  fail %d  total %d\n' "$PASS" "$FAIL" "$N"
[ "$FAIL" -eq 0 ]
