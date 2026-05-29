#!/bin/bash
# Install the csl CLI onto your PATH (symlink → this repo's bin/csl).
#
#   ./install.sh            # symlink into ~/.local/bin
#   PREFIX=~/bin ./install.sh
#
# Idempotent. Backs up any existing non-symlink csl once.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO/bin/csl"
PREFIX="${PREFIX:-$HOME/.local/bin}"
DEST="$PREFIX/csl"

command -v jq >/dev/null 2>&1 || { echo "warning: jq not found — csl needs it (brew install jq)"; }

mkdir -p "$PREFIX"
chmod +x "$SRC"

# Preserve a real (non-symlink) csl once, then symlink.
if [ -e "$DEST" ] && [ ! -L "$DEST" ] && [ ! -e "$DEST.pre-pkg.bak" ]; then
  cp -f "$DEST" "$DEST.pre-pkg.bak"
  echo "backed up existing csl → $DEST.pre-pkg.bak"
fi
ln -sf "$SRC" "$DEST"
echo "installed: $DEST → $SRC"

case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) echo "note: $PREFIX is not on your PATH — add:  export PATH=\"$PREFIX:\$PATH\"" ;;
esac

echo "try:  csl list   |   csl doctor   |   csl set bastille-day"
