# Recording the csl demo GIF

The launch hinges on one **animated** GIF (static screenshots undersell the art).
Here's the exact pipeline. Two clips: the **CLI showcase** (scripted, repeatable)
and the **live status line** (filmed in a real Claude Code session).

## 0. One-time tooling

```bash
brew install asciinema agg     # agg = asciinema-gif generator (Rust)
# or: cargo install --git https://github.com/asciinema/agg
```

## 1. CLI showcase (scripted — safe, repeatable)

`scripts/demo.sh` runs the whole flow against an **isolated** settings.json, so
recording never touches your real status line.

```bash
cd ~/.claude/statusline
asciinema rec -c "bash scripts/demo.sh" csl-demo.cast      # records the run
# tune pacing without re-recording the script: PAUSE_PRE / PAUSE_POST env vars
asciinema play csl-demo.cast                               # preview it
```

Convert to a looping GIF (tuned for README / X / Reddit):

```bash
agg --theme monokai --font-size 22 --speed 1.3 --cols 92 --rows 28 \
    csl-demo.cast csl-demo.gif
```

- Keep `--cols`/`--rows` close to the recording terminal so pixel art doesn't clip.
- `--speed 1.3` tightens dead air; bump if it still feels slow.
- Target < 60 s and a few MB — trim the cast if needed (`asciinema` casts are
  plain JSON you can hand-edit).

## 2. The money shot — live rotating status line (manual)

The per-second sprite rotation only happens in a live Claude Code session
(`refreshInterval: 1`), so film this one for real:

1. `csl set maplestory` (needs the art built once: `csl build maplestory`, or
   any built gallery theme).
2. Open a fresh `claude` session; let the status line animate 3–5 s.
3. Screen-record just the status-line strip:
   - macOS: `⌘⇧5` → record a thin selection over the status line.
   - or `asciinema rec` the whole session if your terminal renders the art.
4. Convert the screen recording to GIF:
   ```bash
   ffmpeg -i statusline.mov -vf "fps=15,scale=900:-1:flags=lanczos" -loop 0 statusline.gif
   ```

## 3. Use them

- **README hero:** the live status-line GIF above the fold (§4 of
  `docs/04-promotion-plan.md` has the full hero structure).
- **Launch posts:** attach the CLI-showcase GIF to the X / Reddit / Show HN
  blurbs in `docs/04-promotion-plan.md`.
- Add a small still per built-in theme (`csl preview <name>` → screenshot) for
  the README theme gallery.

## Storyboard reference

The scene timing lives in `docs/04-promotion-plan.md` §4 ("Demo storyboard").
`scripts/demo.sh` already encodes scenes 1–6 of that storyboard.
