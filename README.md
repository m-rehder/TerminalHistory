# Terminal History

An extension for the **Apple Terminal** (macOS) that stores every command you
enter in a persistent list — kept even after the terminal is closed.
Passwords and secrets are automatically redacted.

Since Terminal.app itself has no plugin system, the solution is based on a
**zsh hook** (zsh is the default shell on macOS).

## Installation

```bash
cd /path/to/TerminalHistory
./install.sh
source ~/.zshrc
```

The installer registers the hook in your `~/.zshrc` and sets up the `th` command.

## Usage

| Command | Description |
|---------|-------------|
| `th` | **Interactive picker** – select a command with ↑/↓ or a mouse click, Enter copies it to the command line (without executing) |
| `th -l` | Show the last 50 commands |
| `th -n 200` | Show the last 200 commands |
| `th -s "git"` | Search for a term |
| `th -d <id>` | Delete a single entry |
| `th -c` | Clear the entire history (with confirmation prompt) |
| `th -e file.txt` | Export history as text |
| `th -f file.jsonl` | Use a different history file |

### Interactive picker (`th`)

Opens a selectable list (newest commands first). Navigation:

- **↑ / ↓** – move selection
- **PgUp / PgDn / Home / End** – jump
- **Mouse click** – select an entry directly
- **Typing** – live filter (search)
- **Enter** – copy the command to the command line (**not** executed)
- **q / Esc / Ctrl-C** – cancel

The selected command is placed in the current command line via `print -z` – you
can still edit it and then execute it yourself with Enter.

## How it works

- **Recording:** A `preexec` hook captures every command, a `precmd` hook
  adds the exit status afterwards. Entries are stored in
  `~/.terminal_history.jsonl` (JSON Lines).
- **Persistence:** The file survives after the terminal is closed.
- **Password protection:** The `th_redact` function automatically redacts:
  - `VAR=value` assignments containing `PASS`, `PASSWORD`, `PASSWD`, `PWD`, `TOKEN`, `SECRET`, `KEY`, `CREDENTIAL`, `AUTH` (quoted values included)
  - `--password=value`, `--token=value`, `--secret=value`, … (quoted values included)
  - `-pVALUE` (mysql, psql, …) and `sshpass -p VALUE`
  - `-u user:password` / `--user user:password` (curl & co.)
  - `user:password@` in URLs / SSH
- **Size limit:** By default at most 10,000 entries are kept
  (configurable via `TH_MAX_ENTRIES`).

## Configuration

In `terminal_history.zsh` (or as environment variables):

| Variable | Default | Meaning |
|----------|---------|---------|
| `TH_HISTORY_FILE` | `~/.terminal_history.jsonl` | Path to the history file |
| `TH_MAX_ENTRIES` | `10000` | Maximum number of entries (`0` = unlimited) |

## Files

- `terminal_history.zsh` – the zsh hook (recording + redaction)
- `bin/th` – CLI tool for listing, searching, deleting, exporting
- `bin/th-pick` – interactive picker (arrow keys + mouse click)
- `install.sh` – installer for `~/.zshrc`

## Uninstallation

Remove the block between `# >>> terminal-history >>>` and
`# <<< terminal-history <<<` from your `~/.zshrc` and optionally delete
`~/.terminal_history.jsonl`.
