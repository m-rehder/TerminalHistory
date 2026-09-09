# =============================================================================
#  Terminal History - zsh hook
#  Records every entered command to a persistent file.
#  Passwords / secrets are automatically redacted.
#
#  Installation:  source "$(dirname "$0")/terminal_history.zsh"
#  (or via install.sh into ~/.zshrc)
# =============================================================================

# --- Configuration -----------------------------------------------------------
: "${TH_HISTORY_FILE:=$HOME/.terminal_history.jsonl}"
: "${TH_MAX_ENTRIES:=10000}"          # 0 = unlimited

# --- Helper: redact passwords / secrets -------------------------------------
th_redact() {
  local cmd="$1"

  # 1) Inline assignments:  VAR=value
  #    (name contains PASS/PASSWORD/PASSWD/PWD/TOKEN/SECRET/CREDENTIAL/AUTH/…KEY)
  #    The name may also START with the keyword (PASSWORD=…, MYSQL_PWD=…)
  #    and must stand at a token boundary; values may be double-quoted.
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/(^|[[:space:];|&])([A-Za-z0-9_]*(PASS|PASSWORD|PASSWD|PWD|TOKEN|SECRET|CREDENTIAL|AUTH|KEY)[A-Za-z0-9_]*=)("[^"]*"|[^[:space:]]*)/\1\2***REDACTED***/Ig')

  # 2) Long options:  --password=value  --token="va lue"  etc.
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/(--(password|passwd|pass|token|secret|apikey|api-key|access-key|private-key)=)("[^"]*"|[^[:space:]]+)/\1***REDACTED***/Ig')

  # 3) Short options with attached value:  -pVALUE  (mysql, psql, ...)
  #    Only when a value follows directly (no space), otherwise it could be a port.
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/((^|[ ;|&])[A-Za-z0-9_.\/-]+[[:space:]]+-p)[^[:space:]]+/\1***REDACTED***/g')

  # 4) sshpass with space form:  sshpass -p value
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/((^|[ ;|&])sshpass[[:space:]]+-p[[:space:]]+)[^[:space:]]+/\1***REDACTED***/Ig')

  # 5) curl & co.:  -u user:pass   --user=user:pass   --user user:pass
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/((^|[[:space:]])(-u|--user)[[:space:]=][A-Za-z0-9._%+-]+):[^[:space:]]+/\1:***REDACTED***/Ig')

  # 6) user:password@ in URLs / SSH
  #    a) URLs:  //user:pass@
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/(\/\/[A-Za-z0-9._%+-]+):[^@[:space:]]+@/\1:***REDACTED***@/g')
  #    b) Bare:  user:pass@  (at the start or after a space, not after a scheme)
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/((^|[[:space:]])[A-Za-z0-9._%+-]+):[^@[:space:]\/][^@[:space:]]*@/\1:***REDACTED***@/g')

  # 7) Fallback: secret-looking assignment at any position
  #    (e.g. in (PASSWORD=x) or npm _authToken=x). Keeps the variable name
  #    and is idempotent (already redacted values are skipped).
  cmd=$(printf '%s' "$cmd" | sed -E \
    's/([A-Za-z0-9_]*(PASS|PASSWORD|PASSWD|PWD|TOKEN|SECRET|CREDENTIAL|AUTH|KEY)[A-Za-z0-9_]*=)("[^"]*"|[^[:space:]*][^[:space:]]*)/\1***REDACTED***/Ig')

  printf '%s' "$cmd"
}

# --- JSON escape (for safe JSONL storage) ------------------------------------
th_json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  printf '%s' "$s"
}

# --- Logging a command -------------------------------------------------------
th_log() {
  local cmd="$1"
  local redacted
  redacted="$(th_redact "$cmd")"

  # Skip empty / whitespace-only commands
  [[ -z "${redacted//[[:space:]]/}" ]] && return

  local id ts cwd
  id="$(uuidgen 2>/dev/null || printf '%s' "$RANDOM$RANDOM$RANDOM")"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cwd="$PWD"

  # Status is appended in the precmd hook
  _TH_PENDING_ID="$id"
  _TH_PENDING_CMD="$(th_json_escape "$redacted")"
  _TH_PENDING_CWD="$(th_json_escape "$cwd")"
  _TH_PENDING_TS="$ts"
}

# --- Append status & write to file -------------------------------------------
th_flush() {
  # Capture exit status BEFORE the test (the test would overwrite $?)
  local th_status="$?"
  [[ -z "$_TH_PENDING_ID" ]] && return

  local line
  line="{\"id\":\"$_TH_PENDING_ID\",\"ts\":\"$_TH_PENDING_TS\",\"cwd\":\"$_TH_PENDING_CWD\",\"cmd\":\"$_TH_PENDING_CMD\",\"status\":$th_status}"

  {
    printf '%s\n' "$line"
    # Cap file size
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

# --- Register hooks ----------------------------------------------------------
autoload -Uz add-zsh-hook
add-zsh-hook preexec th_log
add-zsh-hook precmd th_flush

# --- Initialization ----------------------------------------------------------
mkdir -p "$(dirname "$TH_HISTORY_FILE")" 2>/dev/null
touch "$TH_HISTORY_FILE" 2>/dev/null
