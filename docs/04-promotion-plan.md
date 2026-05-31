# 04 — Go-To-Market / Promotion Plan

> Honest, actionable launch plan for **claude-statusline** (binary: `csl`), a
> package-manager-style CLI for theming the Claude Code status line.
> Synthesized from competitive + distribution + positioning research.
> Anything depending on the unbuilt remote registry / lockfile / `csl publish`
> is kept on the roadmap only and never implied as shipped.

---

## 1. Positioning

### Tagline

> **csl — a package manager for your Claude Code status line.**

Alt: *"Theme your Claude Code status line like you manage packages: list, build, set, done."*

### Elevator pitch (2 sentences)

> csl is a tiny CLI that turns your Claude Code status line into a themeable
> surface — browse, preview, build, and switch minimal or animated pixel-art
> themes with one command, the same way you'd manage packages. It uses a
> claude-swap model (your `settings.json` is the single source of truth) and a
> recipe-vs-artifact split (generators are committed; rendered frames are
> rebuilt with `csl build`), so themes stay reproducible and your config stays
> clean.

### Name strategy

- **Canonical brand / repo name: `claude-statusline`.** Lead all public-facing
  copy, the repo, and search-discoverable surfaces with this. `csl` is a short,
  collision-prone three-letter acronym (CSL = Citation Style Language, C
  standard libs, etc.), so it is poor for discovery on its own.
- **Binary stays `csl`** for typing brevity.
- **Fallback binary names** if `csl` is taken on a target package index:
  `statusctl` (kubectl-family, unambiguous), `slpack` ("status-line pack"),
  or `tint` (short, evokes coloring a surface — `tint set nord`).

---

## 2. Audience & Differentiation

### Who this is for

Claude Code power users who:

1. Already personalize their terminal (the Starship / oh-my-posh / Nerd-Font crowd).
2. Want **expressive / decorative** output over dense telemetry.
3. Appreciate a clean, npm-style CLI mental model.

This is **distinct** from the "I need live cost / token / rate-limit tracking"
audience. csl is deliberately weakest exactly where those tools are strongest,
so it should **not** try to out-dashboard them.

### The competitive map (name names — honesty reads as confidence)

| Category | Tools | What they own | What csl does differently |
|----------|-------|---------------|---------------------------|
| Configurable info dashboards | [ccstatusline](https://github.com/sirmalloc/ccstatusline), [CCometixLine](https://github.com/Haleclipse/CCometixLine), [claude-powerline](https://github.com/Owloops/claude-powerline) | Cost/token/context/git readouts via TUI or TOML | csl is the **aesthetic layer**, not the metrics layer |
| State-reactive companion sprite | [claude-code-mascot-statusline](https://github.com/TeXmeijin/claude-code-mascot-statusline) | A single active mascot that reacts to 9 session states | csl ships **curated, browseable** static pixel-art galleries + palettes you switch like installing a package |
| Gamification / pets | tokburn evolving pets, Pixel Agents | Companion/evolution mechanics | Not a theme manager; csl exposes a real CLI verb set |
| Prompt engines (model borrowed from) | [Starship](https://starship.rs), [Oh My Posh](https://ohmyposh.dev) | Prompt theming | Neither offers true **one-command theme switching**; csl's claude-swap activation does |

### The one-line moat

> **ccstatusline owns "configurable info display." The mascot tool owns
> "reactive companion." csl owns "browseable pixel-art themepacks managed like
> software."**

Reinforcing differentiators (all verified as shipped):

- **Package-manager identity nobody else has:** real verbs — `list / search /
  info / doctor / build / set / use / next / preview / current / status / init`.
- **Two-tier registry:** built-in tier (repo `themes/`) vs user tier
  (`~/.config/csl/themes`), where user themes override built-ins by name.
- **Recipe-vs-artifact split** (npm vs node_modules): generators committed,
  rendered ANSI frames git-ignored and rebuilt with `csl build`.
- **Zero toolchain:** pure bash, no Node / Rust / bun / cargo install — a real
  friction-reduction win vs every incumbent.
- **Engineered, not a dotfile hack:** dependency-free test suite against
  `CSL_HOME` / `CSL_SETTINGS` fixtures; `csl doctor` self-checks the env.

### Honest scope (must appear in every channel)

- The **remote registry** (`csl tap add` / `install`), **lockfile**, and
  **`csl publish`** are **designed but NOT built**. Today csl is a **local
  theme manager** with a registry on the roadmap. Do not imply a marketplace
  exists.
- A fresh clone ships **nord / minimal / blank** (zero-dep built-ins). The
  animated **maplestory**, **bastille-day**, and **pixel-frames** themes live in
  the user tier — present them as "make/add your own" examples, not as
  out-of-the-box defaults.
- It is an independent hobby project, **not affiliated with Anthropic**.

---

## 3. Distribution Channels (ranked)

Ranked by fit for *this specific audience*. Each channel pins back to the
GitHub release as the source of truth.

### 0. GitHub release — the foundation (do this first)

Every other channel points here, so build it first.

```bash
git tag -s v1.0.0                       # signed tag; never force-push tags
shasum -a 256 csl > SHA256SUMS          # checksums
gh release create v1.0.0 csl-v1.0.0.tar.gz SHA256SUMS --notes-file CHANGELOG.md
gh repo edit --add-topic claude-code,cli,bash,statusline,developer-tools
```

- **Pros:** canonical immutable artifact, free CDN, semver tags.
- **Cons:** zero discovery on its own (topics only help inside GitHub search).
- **Trust:** ship `SHA256SUMS`, GPG-sign the tag, never force-push tags.

### 1. Claude Code plugin / marketplace — highest discovery for this audience

This is the native install surface post-v1.31.3 (the status line was extracted
into a standalone plugin and Anthropic now ships an official marketplace). The
mascot tool already distributes this way; the current git-clone + symlink
install is now the non-standard path.

**Layout (verified format):**

- Marketplace repo: `.claude-plugin/marketplace.json` **at the repo root**,
  listing csl (`{name, source}` minimum).
- Plugin dir `plugins/csl/` with `.claude-plugin/plugin.json`
  (`{name:"csl", description, version:"1.0.0"}`).
- **Gotcha:** only `plugin.json` goes inside `.claude-plugin/`. The
  `commands/`, `skills/`, `hooks/` dirs live at the **plugin root**.
- Ship the bash binary in the plugin root; expose via `skills/csl/SKILL.md`
  (preferred) or a `commands/*.md` slash command that shells out to it.

**Users run:**

```text
/plugin marketplace add JaeggerJose/claude-statusline
/plugin install csl@<marketplace-name>
/plugin marketplace update          # refresh
```

- **Version resolution:** keep a semver in `plugin.json` and bump per release
  for predictable updates (omit it = every commit is a new version).
- **Trust:** do NOT use a reserved/impersonating marketplace name
  (`claude-plugins-official`, `anthropic-marketplace`, etc.). If you submit to
  the Anthropic-managed directory, note it pins every entry with ref + sha.

### 2. npm bin package — strong fit (this audience already has Node)

```json
{ "bin": { "csl": "./bin/csl" }, "files": ["bin", "themes", "lib"], "engines": { "node": ">=16" } }
```

A tiny shell/Node shim execs the bash script. `npm i -g csl` or `npx csl`.

- **Pros:** cross-platform, semver + lockfile updates for free, `npx`
  try-before-install, huge reach.
- **Cons:** pure-bash via npm needs a shim; namespace-squat risk — publish early
  (scope as `@you/csl` if needed).
- **Trust:** `npm publish --provenance` from a GitHub Action (supply-chain
  attestation), 2FA on the account, minimal `files` whitelist.

### 3. Homebrew tap — best for the macOS/Linux dev audience

Repo `homebrew-csl` (the `homebrew-` prefix is required). `Formula/csl.rb`
points `url` at the release tarball with its `sha256` and `bin.install "csl"`.

```bash
brew tap JaeggerJose/csl && brew install csl
```

- **Pros:** native to the audience, automatic checksum verification, clean
  upgrade/uninstall, no sudo.
- **Cons:** personal tap still needs the tap step; bump url+sha each release
  (or `brew bump-formula-pr`).
- **Trust:** the `sha256` in the formula is mandatory and auto-checked by brew.

### 4. `curl | bash` installer — lowest friction, highest trust burden

```bash
curl -fsSL https://raw.githubusercontent.com/JaeggerJose/claude-statusline/v1.0.0/install.sh | bash
```

Inside `install.sh`: `set -euo pipefail`; install to
`${XDG_BIN_HOME:-$HOME/.local/bin}` (**no sudo**); download the **tagged**
tarball; `shasum -a 256 -c SHA256SUMS` **before** moving into place; support
`CSL_INSTALL_DIR`, `--dry-run`, `--version`; print exactly what it will do;
comment heavily.

- **Pros:** lowest user friction, no toolchain needed.
- **Cons:** piping to a shell is the least-trusted pattern.
- **Trust:** in-script checksum verification, pin to a **tag (not `main`)**, no
  sudo, and document the review path:
  `curl ... -o install.sh; less install.sh; bash install.sh`.

### 5. awesome-claude-code listing — high-signal curated discovery

> ⚠️ **Do NOT open a PR and do NOT use `gh`** — it is forbidden and risks a ban
> (the repo is in anti-spam lockdown).

Submit **only** through the web UI issue form:
<https://github.com/hesreallyhim/awesome-claude-code/issues/new?template=recommend-resource.yml>.
A bot validates the form, edits `THE_RESOURCES_TABLE.csv`, and regenerates the
list.

Before submitting, the README must explicitly disclose (their stated bar):

- csl is a **shell tool**;
- whether it makes any **non-Anthropic network calls** (it does not);
- any **telemetry** (none);
- any **shared-system-file writes** (it writes only `~/.claude/settings.json`
  and the user theme dir; **no sudo / no system-wide writes**);
- that it needs **no bypass-permissions mode**;
- a **reproducible clone-and-run validation recipe** (not "watch the magic").

### Cross-cutting trust checklist (apply everywhere)

- [ ] Ship `SHA256SUMS` with every release and verify it in installers.
- [ ] No sudo — install to a user dir (`~/.local/bin` / XDG).
- [ ] Pin versions/tags (+sha in marketplace) — never `main`.
- [ ] GPG-sign tags/checksums; `npm --provenance` on the npm package.
- [ ] Comment `install.sh`; disclose any network/telemetry/permission needs.
- [ ] Provide a reproducible demo so reviewers validate claims without trusting you.

---

## 4. Launch Checklist

### Assets to produce (in priority order)

- [ ] **Demo GIF (the money shot).** A live theme swap that lands emotionally.
      Static screenshots undersell the animated themes — the launch needs motion.
- [ ] **README hero** with the GIF above the fold (structure below).
- [ ] **Per-theme gallery images** (small GIF/PNG each): a calm one (nord/minimal)
      and an animated one (maplestory/bastille-day) so people see the range.
- [ ] **asciinema cast** for the README's copy-paste-able version.
- [ ] `SHA256SUMS` + signed tag on the GitHub release.
- [ ] `.claude-plugin/` manifest scaffolding for the marketplace channel.
- [ ] README security note (the awesome-claude-code disclosure block).

### README hero structure (top to bottom)

1. `# claude-statusline` with the tagline as subtitle.
2. **Animated GIF** immediately under the title (theme swap) — above the fold.
3. One-line install block.
4. 30-second Quickstart: `csl list` → `csl preview nord` → `csl set nord`.
5. **How it works** — 3 bullets: claude-swap activation (settings.json is the
   source of truth), theme = render contract + manifest, recipe-vs-artifact split.
6. **Theme gallery** — small image per built-in (nord, minimal, blank) plus the
   user-tier examples (maplestory, bastille-day) clearly labeled "add your own".
7. **Command reference table** (the verb list).
8. **Make your own theme:** `csl init <name>` → edit palette/art →
   `csl build` → `bash test/run.sh`.
9. **Roadmap (honest):** remote git-tap registry / `csl tap add` / lockfile /
   `csl publish` marked **planned**.
10. **Footer:** license, contributing, "independent hobby project, not
    affiliated with Anthropic."

### Demo storyboard (asciinema → looping GIF, total < 60s)

Terminal ~90×24, large readable font, no typos, caches pre-warmed so builds are
instant. **Respect the Ink `wrap='truncate'` width-clipping constraint** —
detect terminal width (parent-TTY + `stty size`) and keep frames within it so
pixel art never clips to "just the ears."

| Scene | Time | Command | Point |
|-------|------|---------|-------|
| 1 | 0–8s | `csl list` | available themes, active one marked |
| 2 | 8–16s | `csl preview bastille-day` | preview is safe (doesn't commit) |
| 3 | 16–26s | `csl build maplestory` → `csl set maplestory` → fresh `claude` session | **money shot** — live animated sprite line; let it loop 2–3s |
| 4 | 26–34s | `csl next` | one-keystroke switching |
| 5 | 34–42s | `csl doctor` | self-checks env (signals engineered, not a hack) |
| 6 | 42–50s | `csl init demo` (optional) | teases "make your own" |

Export a looping GIF (via agg / asciinema-agg) for X / Reddit / HN where
autoplay video isn't reliable.

---

## 5. Ready-to-Post Launch Blurbs

> Attach the demo GIF to each. Keep the "niche / hobby / not affiliated" honesty —
> it reads as confidence, not weakness.

### X / Twitter

```text
I made csl — a package manager for your Claude Code status line.

`csl list`, `csl build`, `csl set nord` and your status line is themed.
Animated pixel-art themes you can add, or go minimal.

claude-swap activation, reproducible builds, zero deps (pure bash).
Niche, but I scratched my own itch.

GitHub: github.com/JaeggerJose/claude-statusline
```

*(Attach the GIF. Put the link in the first reply if you want max reach.)*

### Reddit — r/ClaudeAI

**Title:** I built a package-manager-style CLI to theme the Claude Code status line (csl)

```text
Like a lot of you I stare at the Claude Code status line all day, so I built a
small tool to make it themeable without hand-editing settings.json.

**csl** treats themes like packages: `csl list / search / info / preview /
build / set`. Switching a theme just rewrites `statusLine.command` in your
settings.json (settings.json stays the single source of truth — no extra state
file to drift). Theme generators are committed; the rendered ANSI frames are
rebuilt locally with `csl build` (think npm vs node_modules), so themes are
reproducible and the repo stays light.

Built-ins are nord / minimal / blank (zero deps). It also ships example
user-tier themes you can add — an animated MapleStory sprite gallery and a
Bastille-Day pixel postcard. Making your own is `csl init <name>`, edit the
palette/art, `csl build`. There's a dependency-free test suite so it never
touches your real settings while testing.

Fully honest: it's niche and it's a hobby project. A remote theme registry
(`csl tap add` / `install`), a lockfile, and `csl publish` are on the roadmap
but not built yet — today it's a local theme manager. Not affiliated with
Anthropic.

Demo GIF + repo: github.com/JaeggerJose/claude-statusline — feedback and theme
PRs welcome.
```

### Show HN

**Title:** Show HN: csl – a package manager for the Claude Code status line

```text
csl is a small CLI for theming the Claude Code status line. It borrows the
package-manager mental model — `csl list / search / info / preview / build /
set` — because that's the interaction I actually wanted.

Two design choices I think are worth a look:

1) Activation is "claude-swap" style: setting a theme rewrites
`statusLine.command` in ~/.claude/settings.json, which stays the single source
of truth. No parallel state file to get out of sync.

2) Recipe vs artifact split: theme art is generated by committed scripts (PIL
drawn large, then downsampled by chafa to the ~48-col sextant resolution the
status line gives you), while the rendered ANSI frames/playlists are git-ignored
and rebuilt with `csl build`. Same relationship as source vs build output, or
npm vs node_modules — the repo stays small and themes stay reproducible.

It's deliberately small and dependency-free (pure bash), with a test suite that
runs against fixtures (CSL_HOME/CSL_SETTINGS overrides) so it never touches your
real config.

Scope, honestly: today it's a local theme manager. A remote theme registry
(`csl tap add` / `install`), a lockfile, and publishing are designed but not
built. It's a personal project, not affiliated with Anthropic.

Repo + demo: github.com/JaeggerJose/claude-statusline. Happy to talk about the
activation model and the art pipeline.
```

---

## Sources & Traceability

- Competitive landscape, distribution-channel formats, and positioning copy
  synthesized from the launch research (this session).
- Shipped-vs-roadmap scope reconciled against
  [02-implementation-status.md](02-implementation-status.md) — built-in themes
  are nord/minimal/blank; maplestory/bastille-day/pixel-frames are user-tier;
  registry / lockfile / publish remain unbuilt.
- Companion design docs: [00-architecture-survey.md](00-architecture-survey.md),
  [01-package-manager-design.md](01-package-manager-design.md).
- Memory note: `memory/claude-statusline-csl.md`.
