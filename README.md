# File Transferer

Automatically transfers files from local drop folders on macOS to a remote Windows server via SCP. Drop a file into a watched folder and it transfers itself — no terminal required.

## How it works

A background daemon (`watcher.sh`) watches two local folders using `fswatch`. When a new file is detected, it waits for the file to finish writing (checks for open file handles and size stability), then SCP-transfers it to the corresponding remote directory. The service runs automatically at login via `launchd` and restarts if it crashes.

```
~/Downloads/Transfer/Movies/  →  Windows: /path/to/Movies/
~/Downloads/Transfer/TV/      →  Windows: /path/to/TV Shows/
```

## Requirements

- macOS
- [Homebrew](https://brew.sh)
- Remote Windows machine running OpenSSH Server with SCP access

## Project structure

```
file-transferer/
├── config.sh      ← your settings (edit this first)
├── watcher.sh     ← the daemon (managed by launchd)
├── install.sh     ← sets everything up
└── uninstall.sh   ← tears everything down
```

## Setup

### 1. Edit `config.sh`

Open `config.sh` and fill in the required values:

```bash
REMOTE_HOST=""          # e.g., "192.168.1.100" or "my-windows-pc.local"
REMOTE_USER=""          # your Windows username
REMOTE_PORT=22          # SSH port (default: 22)
REMOTE_MOVIES_PATH=""   # e.g., "/c/Users/john/Videos/Movies"
REMOTE_TV_PATH=""       # e.g., "/c/Users/john/Videos/TV Shows"
```

> **Windows path format:** Use forward slashes with the drive letter. `C:\Users\John\Videos\Movies` becomes `c:/Users/John/Videos/Movies`.

### 2. Run the installer

```bash
bash install.sh
```

The installer will:
- Install `fswatch` and `sshpass` via Homebrew if not already present
- Create the local watch directories (`~/Downloads/Transfer/Movies` and `~/Downloads/Transfer/TV`)
- Prompt for your Windows SSH password and store it securely in the macOS Keychain
- Register the watcher as a `launchd` login service (starts automatically at login)

### 3. Drop files

Drop a movie or TV show file into the appropriate folder:

```
~/Downloads/Transfer/Movies/   ← movies
~/Downloads/Transfer/TV/       ← TV shows
```

The watcher detects the file, waits for it to finish writing, then transfers it to the remote server. Progress and errors are written to the log file.

## Logs

All activity is logged to:

```
~/Library/Logs/file-transferer.log
```

> **Note:** The log must live under `~/Library/Logs/` — macOS prevents the launchd service from writing to `~/Downloads/` or `~/Documents/`.

Watch live:

```bash
tail -f ~/Library/Logs/file-transferer.log
```

Example log output:

```
[2026-03-28 10:30:00] [INFO] Watcher started
[2026-03-28 10:30:00] [INFO]   Movies : ~/Downloads/Transfer/Movies -> 192.168.1.100:/c/Users/john/Videos/Movies
[2026-03-28 10:30:00] [INFO]   TV     : ~/Downloads/Transfer/TV -> 192.168.1.100:/c/Users/john/Videos/TV Shows
[2026-03-28 10:31:42] [INFO] Detected: The.Batman.2022.mkv
[2026-03-28 10:31:42] [INFO] Waiting for file to finish writing: The.Batman.2022.mkv
[2026-03-28 10:31:55] [INFO] Transfer start: The.Batman.2022.mkv (8.3 GB) -> 192.168.1.100:/c/Users/john/Videos/Movies/
[2026-03-28 10:44:10] [INFO] Transfer complete: The.Batman.2022.mkv
```

## Useful commands

```bash
# Check service status
launchctl list | grep file-transferer

# Stop the service manually
launchctl unload ~/Library/LaunchAgents/com.<username>.file-transferer.plist

# Start the service manually
launchctl load ~/Library/LaunchAgents/com.<username>.file-transferer.plist

# Watch logs live
tail -f ~/Library/Logs/file-transferer.log
```

## Updating your password

Re-run the installer — it will prompt for a new password and update the Keychain entry:

```bash
bash install.sh
```

## Uninstall

```bash
bash uninstall.sh
```

This stops the service, removes the launchd plist, and deletes the Keychain entry. Your local transfer directories and log file are preserved.

## File detection notes

The watcher ignores the following to avoid transferring incomplete or system files:

- Hidden files (`.DS_Store`, dotfiles)
- Browser download temps: `.crdownload`, `.part`, `.download`
- Editor swap files: `.tmp`, `.swp`

Files are only transferred after their size has been stable for ~12 seconds with no open file handles (configurable via `STABILITY_INTERVAL` and `STABILITY_CHECKS` in `config.sh`).
