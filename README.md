# Terminal History

Eine Erweiterung für das **Apple Terminal** (macOS), die jeden eingegebenen Befehl
in einer persistenten Liste speichert – auch nach dem Schließen des Terminals.
Passwörter und Geheimnisse werden automatisch geschwärzt.

Da Terminal.app selbst kein Plugin-System hat, basiert die Lösung auf einem
**zsh-Hook** (zsh ist die Standard-Shell auf macOS).

## Installation

```bash
cd /Users/maik/Projects/TerminalHistory
./install.sh
source ~/.zshrc
```

Der Installer trägt den Hook in deine `~/.zshrc` ein und legt das `th`-Kommando an.

## Verwendung

| Befehl | Beschreibung |
|--------|--------------|
| `th` | **Interaktiver Picker** – Befehl mit ↑/↓ oder Mausklick wählen, Enter kopiert ihn in die Eingabezeile (ohne Ausführen) |
| `th -l` | Letzte 50 Befehle anzeigen |
| `th -n 200` | Letzte 200 Befehle anzeigen |
| `th -s "git"` | Nach einem Begriff suchen |
| `th -d <id>` | Einzelnen Eintrag löschen |
| `th -c` | Komplette History löschen (mit Sicherheitsabfrage) |
| `th -e datei.txt` | History als Text exportieren |
| `th -f datei.jsonl` | Andere History-Datei verwenden |

### Interaktiver Picker (`th`)

Öffnet eine auswählbare Liste (neueste Befehle oben). Navigation:

- **↑ / ↓** – Auswahl bewegen
- **PgUp / PgDn / Home / End** – springen
- **Mausklick** – Eintrag direkt wählen
- **Tippen** – live filtern (Suche)
- **Enter** – Befehl in die Eingabezeile kopieren (wird **nicht** ausgeführt)
- **q / Esc / Ctrl-C** – abbrechen

Der gewählte Befehl landet per `print -z` in der aktuellen Eingabezeile – du kannst ihn
noch bearbeiten und dann selbst mit Enter ausführen.

## Wie es funktioniert

- **Aufzeichnung:** Ein `preexec`-Hook fängt jeden Befehl ab, ein `precmd`-Hook
  trägt den Exit-Status nach. Gespeichert wird in
  `~/.terminal_history.jsonl` (JSON Lines).
- **Persistenz:** Die Datei bleibt nach dem Schließen des Terminals erhalten.
- **Passwort-Schutz:** Die Funktion `th_redact` schwärzt automatisch:
  - `VAR=wert`-Zuweisungen mit `PASS`, `PASSWORD`, `PASSWD`, `PWD`, `TOKEN`, `SECRET`, `KEY`, `CREDENTIAL`, `AUTH` (auch in Anführungszeichen)
  - `--password=wert`, `--token=wert`, `--secret=wert`, … (auch in Anführungszeichen)
  - `-pWERT` (mysql, psql, …) und `sshpass -p WERT`
  - `-u benutzer:passwort` / `--user benutzer:passwort` (curl & Co.)
  - `benutzer:passwort@` in URLs / SSH
- **Größenbegrenzung:** Standardmäßig werden max. 10.000 Einträge behalten
  (einstellbar über `TH_MAX_ENTRIES`).

## Konfiguration

In `terminal_history.zsh` (oder als Umgebungsvariable):

| Variable | Standard | Bedeutung |
|----------|----------|-----------|
| `TH_HISTORY_FILE` | `~/.terminal_history.jsonl` | Pfad zur History-Datei |
| `TH_MAX_ENTRIES` | `10000` | Maximale Anzahl Einträge (`0` = unbegrenzt) |

## Dateien

- `terminal_history.zsh` – der zsh-Hook (Aufzeichnung + Schwärzung)
- `bin/th` – CLI-Tool zum Anzeigen, Suchen, Löschen, Exportieren
- `bin/th-pick` – interaktiver Picker (Cursor-Tasten + Mausklick)
- `install.sh` – Installer für `~/.zshrc`

## Deinstallation

Entferne den Block zwischen `# >>> terminal-history >>>` und
`# <<< terminal-history <<<` aus deiner `~/.zshrc` und lösche optional
`~/.terminal_history.jsonl`.
