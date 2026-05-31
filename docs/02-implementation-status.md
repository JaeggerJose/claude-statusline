# Implementation Status

> What of the [package-manager design](01-package-manager-design.md) is actually
> shipped, verified by `test/run.sh` (52 checks, all green). Updated 2026-05-29.

## Shipped (migration steps 1–3)

| Pillar / step | Status | Where |
|---------------|--------|-------|
| **Manifest layer** (step 1) | ✅ done | `themes/<name>.json` for all 6 themes; `csl` reads them |
| Manifest-aware `list` (version column) | ✅ | `bin/csl` `cmd_list` |
| `csl info <name>` (manifest + build state) | ✅ | `cmd_info` |
| `csl search [q]` (name/description) | ✅ | `cmd_search` |
| `csl doctor [name]` (bin/python/truecolor) | ✅ | `cmd_doctor`, reads `requires{}` |
| **`csl build`** recipe runner (step 3) | ✅ | `cmd_build` runs `manifest.art.build` in `art.dir`, exports `$CSL_GEN` |
| Recipe ↔ artifact separation (pillar #6) | ✅ | `art.build` recipe committed; frames/playlist git-ignored; `bastille/build.sh` |
| Activate (pillar #4) | ✅ (pre-existing) | `cmd_set` rewrites settings.json atomically |
| `csl init` (scaffold .sh + .json) | ✅ | `cmd_init` |
| Testability hooks `CSL_HOME`/`CSL_SETTINGS` | ✅ | top of `bin/csl`; used by `test/run.sh` |
| Installable repo (`bin/csl` + `install.sh`) | ✅ | symlinked onto PATH |
| Test suite | ✅ | `test/run.sh`, 52 checks |
| **Portability hardening** (distribution) | ✅ | `run.sh`+`bin/csl` self-locate via `BASH_SOURCE` (no hardcoded `~/.claude` path); `csl set` bootstraps a missing `settings.json`; quoted engine path for homes with spaces; jq deferred so `help`/`path`/`edit` run bare; `doctor` checks UTF-8 locale; default theme = zero-dep `nord` |
| **Two-tier themes** (built-in vs user) | ✅ | `lib/paths.sh` shared by `bin/csl`+`run.sh`: built-in tier = repo `themes/` (ships `nord`/`minimal`/`blank`); user tier = `~/.config/csl/themes` (`CSL_USER_DIR`), overrides built-ins by name; `csl init` writes there; `list`/`info` show origin. Personal themes (`maplestory`/`bastille-day`/`pixel-frames`) moved to the user tier so cloning the tool no longer ships them |
| **Security + correctness fixes** (audit `docs/03`) | ✅ | `csl_valid_name` allowlist in `lib/paths.sh` (kills theme-name path traversal + `set` command injection), enforced in `require_theme`/`cmd_init`; `jq empty` preflight in `cmd_set` (clear JSONC error, file left untouched); render bar clamped to 0–100 with `for ((…))` loops (BSD-`seq` width bug); `count` file CRLF-hardened; `help` no longer leaks code; `doctor` empty-array guard. Each fix has a TDD regression test |
| **Claude Code plugin packaging** | ✅ | `.claude-plugin/{marketplace.json,plugin.json}` + `commands/{setup,run}.md`. `/plugin marketplace add JaeggerJose/claude-statusline` → `/csl:setup` copies the tool to a stable `~/.claude/statusline` and wires the status line there (plugins can't set `statusLine` directly post-v1.31.3, and the plugin dir is versioned/moves); `/csl:run <args>` drives the CLI |

## Design choice that differs from the doc

The doc's §2 sketches **themepack directories**
(`themepacks/<name>/{manifest.json,theme.sh,art/,build/}`). Shipped instead is
the lower-risk **flat manifest** (step 1): `themes/<name>.json` beside
`themes/<name>.sh`. The renderer (`run.sh`/`render.sh`) needed **zero** changes.
Promoting to full themepack dirs (step 2) remains future work.

## Not yet shipped (steps 4–5)

| Pillar / step | Status | Note |
|---------------|--------|------|
| **Registry / git taps** (pillar #2, step 4) | ⬜ todo | `csl tap add`, `csl update`, `csl install <name>` from a remote repo |
| Remote `search` across taps | ⬜ todo | today `search` is local-only |
| **Lockfile** `csl.lock.json` (pillar #5) | ⬜ todo | pin resolved version + source commit |
| `csl upgrade` / `pack` / `publish` | ⬜ todo | distribution lifecycle |
| Themepack directory migration (step 2) | ⬜ todo | move each theme into its own dir |

## Verification (closing the loop)

```bash
$ bash test/run.sh
…
1..52
# pass 52  fail 0  total 52   (exit 0)

$ csl build bastille-day        # recipe → 18 frames → playlist
✓ built bastille-day
$ csl info bastille-day          # → art: built (18 frames)
$ csl doctor bastille-day        # → all good (chafa, python3, PIL, truecolor)
```
