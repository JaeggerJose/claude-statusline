---
description: "Install csl to a stable location, put it on your PATH, and wire the Claude Code status line to a starting theme. Usage: /csl:setup [theme] (default: nord)."
allowed-tools: ["Bash"]
---

# /csl:setup — install csl + wire the status line

Set up `csl` so it survives plugin updates. The plugin lives at a versioned path
(`${CLAUDE_PLUGIN_ROOT}`) that moves on update, so we install a copy to a STABLE
home and point the status line there.

Theme to activate: `$ARGUMENTS` — if empty, use **nord** (a zero-dependency
built-in that works everywhere).

Carry out these steps, then report concisely:

1. **Preflight.** Confirm `jq` exists (`command -v jq`). If missing, stop and tell
   the user to install it (`brew install jq` on macOS, `apt-get install -y jq` on
   Debian/Proxmox) — csl can't edit settings.json without it.

2. **Sync to a stable home.** Use `DEST="$HOME/.claude/statusline"`.
   - If `$DEST/.git` exists, it's a git checkout the user manages — leave it and
     use it as-is (don't clobber).
   - Otherwise copy the tool out of the plugin bundle, preserving any built-ins:
     ```bash
     SRC="${CLAUDE_PLUGIN_ROOT}"; DEST="$HOME/.claude/statusline"
     mkdir -p "$DEST"
     cp -R "$SRC/run.sh" "$SRC/install.sh" "$SRC/bin" "$SRC/lib" "$SRC/themes" "$DEST/"
     ```
   - Never touch `~/.config/csl/themes` (the user's personal theme tier).

3. **Put `csl` on PATH.** `bash "$DEST/install.sh"` (symlinks `csl` → `~/.local/bin`).
   If `~/.local/bin` isn't on PATH, tell the user the exact line to add.

4. **Wire the status line** to the chosen theme via the STABLE copy (so the
   written `statusLine.command` points at `$DEST/run.sh`, not the plugin path):
   ```bash
   "$HOME/.local/bin/csl" set <THEME>     # <THEME> = $ARGUMENTS or nord
   ```
   csl backs up settings.json to `settings.json.csl.bak` and validates the JSON
   before writing.

5. **Verify + report.** Run `csl current` and `csl status`; show the resulting
   `statusLine.command`. Tell the user:
   - the status line updates within ~1s (or on the next Claude Code session);
   - they can now run `csl` directly in their shell, or `/csl:run <args>` here;
   - `csl list` shows themes, `csl set <name>` switches, `csl init <name>` makes
     their own (lands in `~/.config/csl/themes`).

Keep it honest: if any step fails, surface the real error and stop — don't claim
success without the verify output.
