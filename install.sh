#!/bin/zsh
# =============================================================================
#  Terminal History – Installer
#  Trägt den zsh-Hook in die ~/.zshrc ein und macht das th-Tool nutzbar.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_FILE="$SCRIPT_DIR/terminal_history.zsh"
TH_BIN="$SCRIPT_DIR/bin/th"
TH_PICK="$SCRIPT_DIR/bin/th-pick"
ZSHRC="$HOME/.zshrc"

# --- Tools ausführbar machen ------------------------------------------------
chmod +x "$TH_BIN" "$TH_PICK" 2>/dev/null || true

# --- Hook in .zshrc eintragen (idempotent, upgrade-fähig) -------------------
# Zwei Marker (Anfang/Ende) rahmen den verwalteten Block ein. Nur wenn die
# source-Zeile UND die th()-Funktion vorhanden sind, ist alles aktuell.
# Ansonsten wird der alte Block inkl. veralteter Alias-Zeilen ersetzt.
MARKER_START="# >>> terminal-history >>>"
MARKER_END="# <<< terminal-history <<<"

if grep -qF "$HOOK_FILE" "$ZSHRC" 2>/dev/null \
   && grep -q '^th()' "$ZSHRC" 2>/dev/null \
   && ! grep -qE '^[[:space:]]*alias[[:space:]]+th=' "$ZSHRC" 2>/dev/null; then
  echo "Hook und Funktion th() sind bereits aktuell in $ZSHRC eingetragen."
else
  TMP="$(mktemp -t terminal_history 2>/dev/null || mktemp)"
  sed \
    -e '/>>> terminal-history >>>/,/<<< terminal-history <<</d' \
    -e '/^[[:space:]]*alias[[:space:]]\+th=/d' \
    "$ZSHRC" > "$TMP" && mv "$TMP" "$ZSHRC"

  cat >> "$ZSHRC" <<EOF

$MARKER_START
source "$HOOK_FILE"
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
  echo "Hook und Funktion th() in $ZSHRC eingetragen."
fi

echo ""
echo "Fertig! Damit es wirksam wird:"
echo "  source ~/.zshrc"
echo ""
echo "Verwendung:"
echo "  th              # interaktiver Picker (↑/↓ oder Maus, Enter = kopieren)"
echo "  th -l           # letzte 50 Befehle anzeigen"
echo "  th -n 200       # letzte 200 anzeigen"
echo "  th -s 'git'     # nach 'git' suchen"
echo "  th -d <id>      # einzelnen Eintrag löschen"
echo "  th -c           # komplette History löschen"
echo ""
echo "History-Datei: $HOME/.terminal_history.jsonl"
