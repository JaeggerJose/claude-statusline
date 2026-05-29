# Implementation Status

> What of the [package-manager design](01-package-manager-design.md) is actually
> shipped, verified by `test/run.sh` (47 checks, all green). Updated 2026-05-29.

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
| Test suite | ✅ | `test/run.sh`, 47 checks |

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
1..47
# pass 47  fail 0  total 47   (exit 0)

$ csl build bastille-day        # recipe → 18 frames → playlist
✓ built bastille-day
$ csl info bastille-day          # → art: built (18 frames)
$ csl doctor bastille-day        # → all good (chafa, python3, PIL, truecolor)
```
