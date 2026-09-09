# =============================================================================
#  Terminal History – zsh Hook
#  Zeichnet jeden eingegebenen Befehl in einer persistenten Datei auf.
#  Passwörter / Geheimnisse werden automatisch geschwärzt.
#
#  Installation:  source "$(dirname "$0")/terminal_history.zsh"
#  (oder via install.sh in die ~/.zshrc eintragen)
# =============================================================================

# --- Konfiguration -----------------------------------------------------------
: "${TH_HISTORY_FILE:=$HOME/.terminal_history.jsonl}"
: "${TH_MAX_ENTRIES:=10000}"          # 0 = unbegrenzt

# --- Hilfsfunktion: Passwörter / Geheimnisse schwärzen -----------------------
th_redact() {
  local cmd="$1"

  # 1) Inline-Zuweisungen:  VAR=wert
  #    (Name enthält PASS/PASSWORD/PASSWD/PWD/TOKEN/SECRET/CREDENTIAL/AUTH/…KEY)
  #    Der Name darf auch DIREKT mit dem Keyword beginnen (PASSWORD=…, MYSQL_PWD=…)
  #    und muss an einer Token-Grenze stehen; Werte dürfen doppelt gequotet sein.
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/(^|[[:space:];|&])([A-Za-z0-9_]*(PASS|PASSWORD|PASSWD|PWD|TOKEN|SECRET|CREDENTIAL|AUTH|KEY)[A-Za-z0-9_]*=)("[^"]*"|[^[:space:]]*)/\1\2***REDACTED***/Ig')

  # 2) Lange Optionen:  --password=wert  --token="we rt"  usw.
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/(--(password|passwd|pass|token|secret|apikey|api-key|access-key|private-key)=)("[^"]*"|[^[:space:]]+)/\1***REDACTED***/Ig')

  # 3) Kurze Optionen mit direktem Wert:  -pWERT  (mysql, psql, ...)
  #    Nur wenn direkt ein Wert folgt (kein Leerzeichen), sonst ist es z.B. ein Port.
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/((^|[ ;|&])[A-Za-z0-9_.\/-]+[[:space:]]+-p)[^[:space:]]+/\1***REDACTED***/g')

  # 4) sshpass mit Leerzeichen-Form:  sshpass -p wert
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/((^|[ ;|&])sshpass[[:space:]]+-p[[:space:]]+)[^[:space:]]+/\1***REDACTED***/Ig')

  # 5) curl & Co:  -u user:pass   --user=user:pass   --user user:pass
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/((^|[[:space:]])(-u|--user)[[:space:]=][A-Za-z0-9._%+-]+):[^[:space:]]+/\1:***REDACTED***/Ig')

  # 6) Benutzer:Passwort@ in URLs / SSH
  #    a) URLs:  //user:pass@
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/(\/\/[A-Za-z0-9._%+-]+):[^@[:space:]]+@/\1:***REDACTED***@/g')
  #    b) Bare:  user:pass@  (am Anfang oder nach Leerzeichen, nicht nach Schema)
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/((^|[[:space:]])[A-Za-z0-9._%+-]+):[^@[:space:]\/][^@[:space:]]*@/\1:***REDACTED***@/g')

  # 7) Fallback: geheimnisverdächtige Zuweisung an beliebiger Position
  #    (z.B. in (PASSWORD=x) oder npm _authToken=x). Erhält den Variablennamen
  #    und ist idempotent (bereits geschwärzte Werte werden übersprungen).
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/([A-Za-z0-9_]*(PASS|PASSWORD|PASSWD|PWD|TOKEN|SECRET|CREDENTIAL|AUTH|KEY)[A-Za-z0-9_]*=)("[^"]*"|[^[:space:]*][^[:space:]]*)/\1***REDACTED***/Ig')

  printf '%s' "$cmd"
}

# --- JSON-Escape (für sicheres Speichern in JSONL) ---------------------------
th_json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  printf '%s' "$s"
}

# --- Loggen eines Befehls ----------------------------------------------------
th_log() {
  local cmd="$1"
  local redacted
  redacted="$(th_redact "$cmd")"

  # Leere / nur-Whitespace-Befehle überspringen
  [[ -z "${redacted//[[:space:]]/}" ]] && return

  local id ts cwd
  id="$(uuidgen 2>/dev/null || printf '%s' "$RANDOM$RANDOM$RANDOM")"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cwd="$PWD"

  # Status wird im precmd-Hook nachgetragen
  _TH_PENDING_ID="$id"
  _TH_PENDING_CMD="$(th_json_escape "$redacted")"
  _TH_PENDING_CWD="$(th_json_escape "$cwd")"
  _TH_PENDING_TS="$ts"
}

# --- Status nachtragen & in Datei schreiben ----------------------------------
th_flush() {
  # Exit-Status VOR dem Test erfassen (der Test würde $? überschreiben)
  local th_status="$?"
  [[ -z "$_TH_PENDING_ID" ]] && return

  local line
  line="{\"id\":\"$_TH_PENDING_ID\",\"ts\":\"$_TH_PENDING_TS\",\"cwd\":\"$_TH_PENDING_CWD\",\"cmd\":\"$_TH_PENDING_CMD\",\"status\":$th_status}"

  {
    printf '%s\n' "$line"
    # Datei auf Maximalgröße begrenzen
    if (( TH_MAX_ENTRIES > 0 )); then
      local count
      count="$(wc -l < "$TH_HISTORY_FILE" 2>/dev/null || echo 0)"
      if (( count > TH_MAX_ENTRIES )); then
        tail -n "$TH_MAX_ENTRIES" "$TH_HISTORY_FILE" > "$TH_HISTORY_FILE.tmp.$$" 2>/dev/null \
          && mv "$TH_HISTORY_FILE.tmp.$$" "$TH_HISTORY_FILE" \
          || rm -f "$TH_HISTORY_FILE.tmp.$$" 2>/dev/null
      fi
    fi
  } >> "$TH_HISTORY_FILE" 2>/dev/null

  _TH_PENDING_ID=""
}

# --- Hooks registrieren ------------------------------------------------------
autoload -Uz add-zsh-hook
add-zsh-hook preexec th_log
add-zsh-hook precmd th_flush

# --- Initialisierung ---------------------------------------------------------
mkdir -p "$(dirname "$TH_HISTORY_FILE")" 2>/dev/null
touch "$TH_HISTORY_FILE" 2>/dev/null
