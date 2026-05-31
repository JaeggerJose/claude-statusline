---
description: "Drive the csl status-line theme manager from inside Claude Code. Usage: /csl:run <args> — e.g. /csl:run list, /csl:run preview nord, /csl:run set nord, /csl:run doctor."
allowed-tools: ["Bash"]
---

# /csl:run — run the csl CLI

Run the bundled `csl` binary with the user's arguments and show its output
verbatim. This works straight from the plugin bundle, even before `/csl:setup`.

The user's arguments are: `$ARGUMENTS`

Steps:

1. Run csl with those arguments (default to `list` when none were given):

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/bin/csl" $ARGUMENTS
   ```

2. Show the output exactly. Do not reformat the status-line preview — ANSI
   colors are intentional.

Notes to relay only if relevant:

- `csl set <theme>` rewrites `~/.claude/settings.json` → `statusLine.command`.
  Run from the plugin bundle, that command points at the plugin's (versioned)
  path, which moves when the plugin updates. For a stable status line that
  survives updates, run **`/csl:setup`** once — it installs csl to
  `~/.claude/statusline` and wires the status line to that fixed location.
- `csl` needs `jq`. If it errors that jq is missing, tell the user to install it
  (`brew install jq` / `apt-get install -y jq`).
