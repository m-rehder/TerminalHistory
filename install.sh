#!/bin/zsh
# =============================================================================
#  Terminal History - Installer
#  Registers the zsh hook in ~/.zshrc and makes the th tool usable.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_FILE="$SCRIPT_DIR/terminal_history.zsh"
TH_BIN="$SCRIPT_DIR/bin/th"
TH_PICK="$SCRIPT_DIR/bin/th-pick"
ZSHRC="$HOME/.zshrc"

# --- Make the tools executable ------------------------------------------------
chmod +x "$TH_BIN" "$TH_PICK" 2>/dev/null || true

# --- Register hook in .zshrc (idempotent, upgrade-safe) -----------------------
# Two markers (start/end) frame the managed block. Only when the
# source line AND the th() function are present is everything current.
# Otherwise the old block including outdated alias lines is replaced.
MARKER_START="# >>> terminal-history >>>"
MARKER_END="# <<< terminal-history <<<"

if grep -qF "$HOOK_FILE" "$ZSHRC" 2>/dev/null \
   && grep -q '^th()' "$ZSHRC" 2>/dev/null \
   && grep -qF 'unalias th' "$ZSHRC" 2>/dev/null \
   && ! grep -qE '^[[:space:]]*alias[[:space:]]+th=' "$ZSHRC" 2>/dev/null; then
  echo "Hook and th() function are already up to date in $ZSHRC."
else
  TMP="$(mktemp -t terminal_history 2>/dev/null || mktemp)"
  sed \
    -e '/>>> terminal-history >>>/,/<<< terminal-history <<</d' \
    -e '/^[[:space:]]*alias[[:space:]]\+th=/d' \
    "$ZSHRC" > "$TMP" && mv "$TMP" "$ZSHRC"

  cat >> "$ZSHRC" <<EOF

$MARKER_START
source "$HOOK_FILE"
# A possibly still active old alias th=... would break parsing of the
# function definition below ("parse error near ()") – remove it.
unalias th 2>/dev/null || true
th() {
  if [[ \$# -eq 0 ]]; then
    local tmp picked
    tmp="\$(mktemp -t th-pick 2>/dev/null || mktemp)"
    "$TH_PICK" "\${TH_HISTORY_FILE:-\$HOME/.terminal_history.jsonl}" "\$tmp"
    picked="\$(< "\$tmp")"
    rm -f "\$tmp"
    if [[ -n "\$picked" && "\$picked" != "__TH_NO_SELECT__" ]]; then
      print -z -- "\$picked"
    fi
  else
    "$TH_BIN" "\$@"
  fi
}
$MARKER_END
EOF
  echo "Hook and th() function registered in $ZSHRC."
fi

echo ""
echo "Done! To activate it:"
echo "  source ~/.zshrc"
echo ""
echo "Usage:"
echo "  th              # interactive picker (↑/↓ or mouse, Enter = copy)"
echo "  th -l           # show the last 50 commands"
echo "  th -n 200       # show the last 200"
echo "  th -s 'git'     # search for 'git'"
echo "  th -d <id>      # delete a single entry"
echo "  th -c           # clear the whole history"
echo ""
echo "History file: $HOME/.terminal_history.jsonl"
