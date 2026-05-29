# `csl` as a Status-Line Package Manager — Design

> Evolving `csl` from a *theme switcher* into a *themepack package manager*,
> in the spirit of `apt` / `pip` / `npm` / `brew` / `claude-swap`.

## 1. The mental model (底層邏輯)

Every package manager — apt, pip, npm, brew, claude-swap — is built from the
same six pillars. `csl` already has #4 (activate); it's missing #1, #2, #6.

| # | Pillar | apt / npm / brew | `csl` today | `csl` target |
|---|--------|------------------|-------------|--------------|
| 1 | **Self-describing package** (manifest) | `control` / `package.json` / formula | metadata in `.sh` comments, grep'd | `manifest.json` per themepack |
| 2 | **Registry / index** (where packs come from) | `sources.list` / npm registry / tap | none (only local files) | git "tap" repo(s) + local |
| 3 | **Lifecycle verbs** | install/remove/update/upgrade/search | only `list/set/preview/new` | + install/remove/update/upgrade/search/info/build |
| 4 | **Activate / select** | `update-alternatives`, `nvm use` | `csl set` (rewrites settings.json) ✅ | keep |
| 5 | **Dependency & capability resolution** | depends/peerDeps | none | `requires{}` in manifest + `csl doctor` |
| 6 | **Recipe vs artifact separation** | source vs `node_modules` | art mixed with theme | `art/` recipe → `build/` artifacts (gitignored) |

**The one-sentence philosophy:** *a theme stops being a file you hand-edit and
becomes a package you install, build, and activate — described by a manifest,
fetched from a registry, and reproducible from a recipe.*

## 2. The unit: a "themepack" (directory, not a file)

Today a theme = `themes/bastille-day.sh`. Promote it to a self-contained dir:

```
themepacks/
  bastille-day/
    manifest.json      # ① metadata + render mode + deps + art recipe
    theme.sh           # the render contract (palette + SHOW_* toggles)  ← sourced by run.sh
    art/               # ⑥ the RECIPE (committed, small)
      make_bastille.py
      bastille.gif      # source image/anim (or fetched on build)
    build/             # ⑥ the ARTIFACT (gitignored, regenerable)
      frame000.txt …
      playlist
    preview.gif        # optional, for `csl info`
```

Why a directory: it lets one pack own its generator, its source art, its built
frames, and its palette together — the way an npm package owns its `src` +
`package.json`, and `brew` a formula + its bottle.

### Manifest schema (`manifest.json`, parsed with `jq` — already a `csl` dep)

```json
{
  "name": "bastille-day",
  "version": "1.0.0",
  "description": "14 juillet dusk-fireworks postcard — Eiffel Tower, tricolore, lavender, Bordeaux oysters",
  "author": "minghsuan",
  "license": "MIT",
  "render": {
    "mode": "gallery",
    "playlist": "build/playlist",
    "cells_h": 18
  },
  "art": {
    "build": "python3 art/make_bastille.py && bash \"$CSL_GEN\" art/bastille.gif build 48x24",
    "outputs": ["build/playlist"]
  },
  "requires": {
    "bin": ["chafa", "python3"],
    "python": ["PIL"],
    "terminal": "truecolor"
  }
}
```

- `render.mode` replaces today's `ART_MODE` env var — declarative, not buried in `.sh`.
- `art.build` is the **recipe**: the exact command that regenerates `build/`.
  Idempotent (the gen scripts already mtime-guard). `$CSL_GEN` is exported by csl.
- `requires` powers `csl doctor` and a pre-install gate (like apt's Depends:).
- `theme.sh` stays as the palette/contract file `run.sh` sources — unchanged,
  so the renderer (`lib/render.sh` + `run.sh`) needs **zero** changes.

## 3. The registry: git "taps" (brew-style) + local-first

A registry is just a git repo whose `themepacks/<name>/manifest.json` exist.

```
csl tap add  <git-url> [alias]   # register a source (like `brew tap`, apt sources.list)
csl tap list
csl update                       # git pull every tap → refresh the local index cache
csl search [query]               # search across tap indexes + locally installed
csl install <name>[@version]     # copy/sparse-fetch pack from a tap → run art.build → register
```

Why git-taps over a PyPI-style index+tarball server: zero hosting, free
versioning (tags/commits), trivially shareable (`csl tap add github:me/csl-themes`),
and you can publish by `git push`. Local packs work with no tap at all.

## 4. Command map (apt/npm/pip → csl)

| Intent | apt | npm | pip | **csl** |
|--------|-----|-----|-----|---------|
| discover | `apt search` | `npm search` | `pip search` | `csl search [q]` |
| metadata | `apt show` | `npm view` | `pip show` | `csl info <name>` |
| add source | edit sources.list | — | extra-index-url | `csl tap add <url>` |
| refresh index | `apt update` | — | — | `csl update` |
| install | `apt install` | `npm i` | `pip install` | `csl install <name>` |
| (re)build artifacts | (postinst) | `npm run build` | (build) | `csl build <name>` |
| upgrade | `apt upgrade` | `npm update` | `pip install -U` | `csl upgrade [name]` |
| remove | `apt remove` | `npm rm` | `pip uninstall` | `csl remove <name>` |
| list installed | `apt list --installed` | `npm ls` | `pip list` | `csl list` ✅ |
| **activate** | `update-alternatives` | `nvm use` | — | `csl use` / `csl set` ✅ |
| check env | — | `npm doctor` | `pip check` | `csl doctor` |
| package up | `dpkg-deb` | `npm pack` | `build` | `csl pack <name>` |
| publish | — | `npm publish` | `twine upload` | `csl publish <name>` (git push to tap) |

Verbs `csl` keeps as-is: `set/use`, `list`, `preview`, `next`, `status`, `edit`, `path`.
`new` becomes `init` (scaffold a themepack dir + manifest, not a bare `.sh`).

## 5. Reproducibility: a lockfile

`~/.claude/statusline/csl.lock.json` records, per installed pack: resolved
version, source tap + commit, and a content hash of `manifest.json`. Lets
`csl install` be deterministic and `csl doctor` detect drift (artifact older
than recipe → "needs rebuild", like a stale `node_modules`).

## 6. Migration path (no big-bang; each step ships value)

1. **Manifest layer (now):** add `manifest.json` next to each existing
   `themes/<name>.sh`; teach `csl list/info` to read it. Renderer untouched.
2. **Themepack dirs:** move each theme into `themepacks/<name>/{manifest.json,theme.sh,art/,build/}`. `run.sh` resolves `themepacks/<n>/theme.sh` (fallback to old `themes/<n>.sh`).
3. **`csl build` + `requires`/`doctor`:** wire `art.build` + capability checks. Bastille & maple become buildable packs.
4. **`csl tap` + `install`/`search`/`update`:** git-registry. Publish your packs to `github:minghsuan/csl-themes`.
5. **`csl.lock` + `upgrade`/`pack`/`publish`:** reproducibility + distribution.

## 7. What stays simple (三板斧 / no over-engineering)

- No daemon, no DB — the filesystem **is** the state; `settings.json` **is** the
  active-theme source of truth (already true).
- jq is the only parser. bash 3.2-compatible (macOS).
- A pack with no `art.build` and no tap is just a palette `.sh` — the cheap case
  stays a one-file edit. Complexity is opt-in per pack.
