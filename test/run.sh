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

# Isolated user-theme tier so tests never see the real ~/.config/csl/themes.
USERT="$TMP/usert"; mkdir -p "$USERT"

# csl invoked against the repo + fixture settings + isolated user tier.
csl() { CSL_HOME="$REPO" CSL_SETTINGS="$FIX" CSL_USER_DIR="$USERT" CSL_GEN="$HOME/.claude/statusline-gen-art.sh" bash "$CSL" "$@"; }

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

# 5. info prints version + origin (built-in themes ship in the repo)
assert_contains "info nord shows version" "$(csl info nord)" "1.0.0"
assert_contains "info nord shows origin"  "$(csl info nord)" "built-in"

# 6. search matches by name and by description (against built-in themes)
assert_contains "search 'nord' finds nord"          "$(csl search nord)"       "nord"
assert_contains "search 'monochrome' finds minimal" "$(csl search monochrome)" "minimal"

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

# 13. cmd_set bootstraps a missing settings.json (fresh-machine first run)
FRESH="$TMP/fresh/settings.json"
CSL_HOME="$REPO" CSL_SETTINGS="$FRESH" bash "$CSL" set nord >/dev/null 2>&1 || true
assert_ok test -f "$FRESH"
assert_ok jq empty "$FRESH"
assert_contains "bootstrap wrote command" "$(jq -r '.statusLine.command' "$FRESH" 2>/dev/null)" "run.sh nord"

# 14. run.sh self-locates when the repo is relocated (no hardcoded ~/.claude path)
REL="$TMP/relocated"
mkdir -p "$REL/lib" "$REL/themes"
cp "$REPO/run.sh" "$REL/run.sh"
cp "$REPO/lib/render.sh" "$REL/lib/render.sh"
cp "$REPO/lib/paths.sh"  "$REL/lib/paths.sh"
cp "$REPO"/themes/nord.sh "$REL/themes/nord.sh"
relout=$(CSL_USER_DIR="$REL/none" printf '%s' "$sample" | CSL_USER_DIR="$REL/none" bash "$REL/run.sh" nord 2>/dev/null)
assert_contains "relocated run.sh renders from its own dir" "$relout" "Opus 4.8"

# 15. two-tier resolution: user-tier theme is listed (tagged user) + overrides built-in
printf 'THEME_DESC="my user theme"\nART_MODE="none"\n' > "$USERT/zzmine.sh"
assert_contains "user theme shows in list" "$(csl list)" "zzmine"
assert_ok       csl preview zzmine
printf 'THEME_DESC="OVERRIDE"\nART_MODE="none"\n' > "$USERT/nord.sh"   # shadow built-in nord
assert_contains "user tier overrides built-in by name" "$(csl info nord)" "user"
rm -f "$USERT/nord.sh" "$USERT/zzmine.sh"   # don't bleed into the guard check

# 16. security: name validation blocks traversal + injection AT THE SOURCE.
# Plant an evil .sh OUTSIDE the theme dirs; a traversal name would source it.
EVIL="$TMP/evil"; mkdir -p "$EVIL"; MARK="$TMP/evil_ran"; rm -f "$MARK"
printf 'touch "%s"\n' "$MARK" > "$EVIL/x.sh"   # sourcing this creates MARK
assert_fail csl preview '../evil/x'             # USERT/../evil/x.sh resolves to the bomb
assert_ok   test ! -e "$MARK"                   # proves the bomb was NOT sourced
assert_fail csl preview '../../etc/passwd'      # classic traversal
# init must refuse metachar names — that's the gate that would otherwise let a
# `csl set <metachar>` persist an injection into statusLine.command.
assert_fail csl init 'evil;touch /tmp/csl_pwn;#'
assert_fail csl init 'bad/name'
assert_fail csl init 'a b'
assert_eq   "rejected ops leave nord active" "$(csl current | tr -d '\n')" "nord"

# 17. JSONC settings.json → set fails loudly + leaves the file untouched
JSONC="$TMP/jsonc/settings.json"; mkdir -p "$TMP/jsonc"
printf '{\n  // a comment\n  "model": "x"\n}\n' > "$JSONC"
jmsg=$(CSL_HOME="$REPO" CSL_USER_DIR="$USERT" CSL_SETTINGS="$JSONC" bash "$CSL" set nord 2>&1 || true)
assert_contains "JSONC set error mentions JSON" "$jmsg" "JSON"
assert_contains "JSONC settings left untouched" "$(cat "$JSONC")" "// a comment"

# 18. context bar is always exactly 10 cells (BSD seq + clamp regressions)
barcells() { ( source "$RENDER"; source "$THEMES/nord.sh"
  render '{"model":{"display_name":"M"},"workspace":{"current_dir":"/t"},"context_window":{"used_percentage":'"$1"'}}'
) | grep -o '[█░]' | wc -l | tr -d ' '; }
assert_eq "bar=10 cells at 0%"   "$(barcells 0)"   "10"
assert_eq "bar=10 cells at 100%" "$(barcells 100)" "10"
assert_eq "bar=10 cells at 130%" "$(barcells 130)" "10"

# 19. help must not leak code below the comment header
assert_contains "help shows the verb table" "$(csl help)" "csl list"
hh=$(csl help)
case "$hh" in *"set -euo pipefail"*|*"_csl_repo"*) no "help leaks code";; *) ok "help does not leak code";; esac

# 20. GUARD: the real settings.json was never touched
real_hash_after=$(shasum "$REAL_SETTINGS" 2>/dev/null | awk '{print $1}')
assert_eq "real settings.json untouched" "$real_hash_after" "$real_hash_before"

# --- summary --------------------------------------------------------------
echo "1..$N"
printf '# pass %d  fail %d  total %d\n' "$PASS" "$FAIL" "$N"
[ "$FAIL" -eq 0 ]
