# Bug Audit

Prioritized audit of confirmed findings in the `csl` statusline tool. Severities reflect adjusted ratings after verification (cosmetic statusline glitches and untested-but-correct code paths dominate; the highest live risks are unsanitized theme-name handling and JSONC settings failures).

| Severity | Area | file:line | Issue | Fix |
|----------|------|-----------|-------|-----|
| high | Security | lib/paths.sh:21-25 (consumed run.sh:28, bin/csl:305-306,116) | Theme name never sanitized; `../` traversal in `csl_theme_sh` sources arbitrary `.sh` outside theme dirs. `csl preview '../../tmp/evil/x'` executes attacker file; a traversal token in settings.json is sourced every refresh. | Reject names not matching `^[A-Za-z0-9._-]+$` and explicitly reject `.`/`..`/`/` in `csl_theme_sh`/`csl_theme_json` and `require_theme`. |
| high | Security | bin/csl:277 (`newcmd="bash $RUN $1"`) | `csl set` interpolates unvalidated theme name raw into `.statusLine.command`; a metachar filename (e.g. `zzz;touch PWNED;#`) yields persisted, every-refresh command injection. `cmd_init` will also scaffold metachar-named themes. | Add `valid_name()` allowlist, call it in `require_theme` and `cmd_init`; always single-quote `$1` in the written command. |
| high | UX / install | bin/csl:284-295 (jq pipeline); 75 (settings_cmd) | `csl set`/`next` hard-fail on JSONC settings.json (`//` comments) with raw `parse error...` + misleading "failed to update settings.json"; switch silently no-ops. `settings_cmd` also returns empty, mislabeling active theme as `(custom)`. | `jq empty "$SETTINGS"` up front with an actionable JSONC message; surface the same validation in current/list/status. |
| medium | Shell correctness | lib/render.sh:160-162 | `seq 1 0` emits `1\n0` (2 iters) on BSD seq, so the context bar is 12 cells (not 10) at 0-9% and 100%. | Use C-style loops: `for ((i=0;i<filled;i++))` / `for ((i=0;i<empty;i++))`. |
| medium | Shell correctness | lib/render.sh:160-162 | `used_percentage>=100` makes `empty` negative; `seq 1 -1` counts down, flooding the bar (14+ cells at 115%). | Clamp `ctx_int` to 0..100 and use `while [ "$i" -lt "$N" ]` loops (zero-safe on BSD+GNU). |
| medium | Shell correctness | lib/render.sh:186-187 | `printf '%b' "$line"` interprets backslash escapes in runtime data (cwd `proj\new` -> embedded newline; also model/style). | Define palette with `$'\033[...'` ANSI-C quoting and emit with `printf '%s'`. |
| medium | Portability | test/run.sh:38,144 | `shasum` absent on minimal Linux -> both hashes empty -> "real settings.json untouched" guard passes vacuously (false green). | Pick `shasum`/`sha256sum` once and bail if none; emit `absent` sentinel for a missing file. |
| medium | Test gaps | bin/csl:284-289 (test 8) | `set` merge-preservation of sibling keys (model/permissions/hooks) is unasserted; a `jq '{statusLine:...}'` regression would wipe configs undetected. | Seed fixture with sibling keys; assert `.model`/`.permissions` survive a set. |
| medium | Test gaps | bin/csl:225-243 (test 10) | doctor failure path (missing required bin -> rc=1) is untested; only the green `nord` path runs. | Add a user theme requiring a bogus bin; `assert_fail` + assert "some checks failed". |
| medium | Test gaps | bin/csl:328-367 | `csl init` untested: user-tier write, BSD/GNU `sed -i` `__NAME__` substitution, manifest `.name`, no-clobber die. | Add happy-path test; `assert_fail grep -q __NAME__` to catch sed regressions. |
| medium | Test gaps | bin/csl:310-320 | `cmd_next` untested: modulo wraparound and arr[0] fallback from `(custom)`. | Add wraparound (nord->blank) and custom-fallback cases. |
| medium | Test gaps | lib/render.sh:56-107 (test 11) | gallery/frames/sixel/iterm `render_art` paths have zero behavioral coverage (all built-ins are mode=none). | Add a temp-playlist gallery test asserting emitted frame content. |
| medium | Test gaps | bin/csl:275-278 (test 7/14) | Spaces-in-path command-quoting branch never executes (all test paths space-free). | Copy engine into a spaced temp dir, run `set`, assert quoted command present + executable. |
| medium | Test gaps | lib/render.sh:157-169 (test 11) | render boundaries (missing ctx %, 0%) untested; masks the live BSD-seq 0% bar defect. | Add missing-ctx and 0% render assertions (fix the seq bug alongside). |
| low | Shell correctness | bin/csl:375 | `csl help` `sed -n '2,33p'` overshoots the doc block; prints `set -euo pipefail`, comments, `_csl_repo() {`. | Tighten to `2,26p` or use explicit `# >>> usage`/`# <<< usage` markers. |
| low | Shell correctness | bin/csl:214-215 | `cmd_doctor` iterates an empty array under `set -u` -> aborts on bash 3.2 when both theme dirs are empty. | Count-guard `if [ "${#names[@]}" -gt 0 ]` (mirror cmd_next). |
| low | Portability | lib/render.sh:61 | Gallery `total=$(wc -l ...)` undercounts a playlist with no trailing newline; last frame unreachable. | Use `awk 'END{print NR}'`. |
| low | Portability | lib/render.sh:97 | frames `frame_count=$(cat .../count)` aborts arithmetic on CRLF/whitespace (e.g. `48\r`); `:-0` guard misses it. | `frame_count=$(tr -cd '0-9' < "$ART_DIR/count")`. |
| low | Security | run.sh:36 (preview bin/csl:306) | Theme `.sh` files are `source`d every render (~1/s); install = persistent code exec; user-tier shadows built-ins. No tap/registry exists, so no trust boundary crossed. | Document themes-are-code (fix run.sh:9 comment); warn/confirm when a user theme shadows a built-in. |
| low | UX / install | bin/csl:269-296 (detect at 90-100) | `csl set` silently overwrites a non-csl `statusLine.command`; recoverable on first switch but rolling `.csl.bak` loses original after two. | Warn + confirm (with `--force`/`CSL_FORCE` for `next`) when active is `(custom)`; write a once-only `.csl.orig`. |
| low | UX / install | bin/csl:282 | `.csl.bak` overwritten every `set`; cannot recover older than last switch; useless under JSONC. | Add write-once `.csl.orig` snapshot alongside the rolling `.csl.bak`. |
| low | UX / install | install.sh (whole file); main() 384-400 | No uninstall command/script; users can't cleanly remove csl or restore prior status line. | Add `uninstall.sh` + `csl uninstall` restoring from backups; document both. |
| low | UX / install | install.sh:21-25 | Backs up a real `csl` only once; a later different real `csl` is clobbered with no backup/warning. | Always preserve a non-symlink DEST with a timestamped backup; warn on foreign-symlink replace. |
| low | UX / install | lib/render.sh:56-67; cmd_set 269-296 | An unbuilt gallery/frames/sixel/iterm theme renders text-only with no hint; `set` doesn't check build state. | Factor `art_built()` helper; print a yellow notice on `set` and extend `csl info` to all art modes. |
| low | UX / install | bin/csl:190-244 | Bare `csl doctor` checks ALL themes' deps; one unused theme's missing bin flips run to fail; active theme not highlighted. | Default to active theme; add `--all`; print scope; or attribute rows to owning theme. |
| low | UX / install | bin/csl:217,220,225 | doctor/build read manifest arrays via unquoted command substitution (word-split + glob); fragile for names with spaces/glob chars. | Collect into arrays via `while IFS= read -r`; iterate quoted. |
| low | Test gaps | bin/csl:90-100,139 | `(custom)` active-theme detection and the cmd_list custom warning are untested (tests only set csl-owned commands). | Add a foreign-command fixture; assert `current == (custom)` and list warns. |

## Quick wins

- **bin/csl:375** — change `2,33p` to `2,26p`: one-token fix, stops `csl help` leaking code.
- **lib/render.sh:160-162** — swap both seq loops for `for ((...))`: kills the 0%/100% and overflow bar-width bugs at once (clamp `ctx_int` in the same edit).
- **bin/csl:214-215** — wrap the doctor loop in `[ "${#names[@]}" -gt 0 ]`: removes a bash 3.2 abort.
- **bin/csl (valid_name)** — add one allowlist validator wired into `require_theme` + `cmd_init`: closes both the traversal (paths.sh:21-25) and the `set` injection (bin/csl:277) at the source.
- **bin/csl:284** — `jq empty` preflight in `cmd_set`: turns the cryptic JSONC failure into an actionable message; also unblocks `next`.
- **lib/render.sh:97** — `tr -cd '0-9'` on the count file: trivial CRLF hardening.

## Won't fix / by-design (downgraded)

- **theme-sh-source-rce** (claimed critical -> low): Sourcing theme `.sh` every render is the intended design and crosses no trust boundary — no tap/registry/remote-install exists, so a malicious theme requires pre-existing user-level write access. Treat as defense-in-depth (document + shadow warning), not a blocker.
- **clobber-custom-statusline / set-bak-overwritten** (claimed high/medium -> low): Taking over `statusLine.command` is the tool's stated job and the first switch is fully recoverable via `.csl.bak`; the real gap is the missing acknowledgement and the two-switch backup loss, addressed by the `.csl.orig` quick win.
- **gallery-unbuilt-silent / doctor-active-theme** (-> low): Discoverability/affordance gaps; the status line still renders fully and every reported check is accurate.
- **install-backup-once-data-loss** (claimed medium -> low): Narrow trigger (stale backup + manually replaced different real `csl` + re-run) on a user-owned install path; documented behavior.
- **Test-gap findings**: The underlying production code is correct in every case — these are missing regression guards, not live defects. Worth adding, but they describe coverage, not bugs.
