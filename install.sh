#!/usr/bin/env bash
# =============================================================================
# File Transferer — Installer
# Run this once (or again to update password/config).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.file-transferer"
PLIST_LABEL="com.$(whoami).file-transferer"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

echo "=== File Transferer — Installer ==="
echo

# -----------------------------------------------------------------------------
# 1. Verify Homebrew is available
# -----------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew is required but not installed."
    echo "Install it from https://brew.sh, then re-run this script."
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. Install dependencies
# -----------------------------------------------------------------------------
echo "Checking dependencies..."

if ! command -v fswatch &>/dev/null; then
    echo "  Installing fswatch..."
    brew install fswatch
else
    echo "  fswatch: already installed"
fi

if ! command -v sshpass &>/dev/null; then
    echo "  Installing sshpass..."
    brew install hudochenkov/sshpass/sshpass
else
    echo "  sshpass: already installed"
fi

if ! command -v terminal-notifier &>/dev/null; then
    echo "  Installing terminal-notifier..."
    brew install terminal-notifier
else
    echo "  terminal-notifier: already installed"
fi

echo

# -----------------------------------------------------------------------------
# 3. Load and validate config
# -----------------------------------------------------------------------------
source "$SCRIPT_DIR/config.sh"

missing=()
[[ -z "$REMOTE_HOST" ]]        && missing+=("REMOTE_HOST")
[[ -z "$REMOTE_USER" ]]        && missing+=("REMOTE_USER")
[[ ${#WATCH_PAIRS[@]} -eq 0 ]] && missing+=("WATCH_PAIRS")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: The following values are missing from config.sh:"
    for field in "${missing[@]}"; do
        echo "  - $field"
    done
    echo
    echo "Open config.sh, fill in the missing values, and re-run install.sh."
    exit 1
fi

echo "Config:"
echo "  Remote host : $REMOTE_HOST (port $REMOTE_PORT)"
echo "  Remote user : $REMOTE_USER"
for pair in "${WATCH_PAIRS[@]}"; do
    local_dir="${pair%%:*}"
    remote_path="${pair##*:}"
    echo "  Watch pair  : $local_dir -> $remote_path"
done
echo "  Log file    : $LOG_FILE"
echo

# -----------------------------------------------------------------------------
# 4. Deploy scripts to ~/.file-transferer/ (outside ~/Documents so launchd
#    can access them without macOS TCC/privacy restrictions)
# -----------------------------------------------------------------------------
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/watcher.sh" "$INSTALL_DIR/watcher.sh"
cp "$SCRIPT_DIR/config.sh"  "$INSTALL_DIR/config.sh"
cp "$SCRIPT_DIR/status.sh"  "$INSTALL_DIR/status.sh"
chmod +x "$INSTALL_DIR/watcher.sh"
chmod +x "$INSTALL_DIR/status.sh"
echo "Scripts deployed to: $INSTALL_DIR"

# -----------------------------------------------------------------------------
# 5. Create local transfer directories and log directory
# -----------------------------------------------------------------------------
for pair in "${WATCH_PAIRS[@]}"; do
    local_dir="${pair%%:*}"
    mkdir -p "$local_dir"
done
mkdir -p "$(dirname "$LOG_FILE")"
echo "Local directories created."

# -----------------------------------------------------------------------------
# 6. Store password in macOS Keychain
#    The -U flag updates the entry if it already exists.
# -----------------------------------------------------------------------------
echo
read -rs -p "Enter the SSH/SCP password for ${REMOTE_USER}@${REMOTE_HOST}: " ssh_password
echo
security add-generic-password \
    -a "$REMOTE_USER" \
    -s "file-transferer" \
    -w "$ssh_password" \
    -U
echo "Password saved to Keychain."

# Clear the variable immediately
unset ssh_password

# -----------------------------------------------------------------------------
# 7. Create the launchd plist
#    Includes both Homebrew paths for Apple Silicon (/opt/homebrew) and Intel (/usr/local)
# -----------------------------------------------------------------------------
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${INSTALL_DIR}/watcher.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_FILE}</string>
    <key>StandardErrorPath</key>
    <string>${LOG_FILE}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
PLIST

echo "launchd plist written to: $PLIST_PATH"

# -----------------------------------------------------------------------------
# 8. Load (or reload) the service
# -----------------------------------------------------------------------------
# Unload silently if already running
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "Service loaded and running."

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo
echo "=== Installation complete ==="
echo
for pair in "${WATCH_PAIRS[@]}"; do
    local_dir="${pair%%:*}"
    echo "  Drop files here : $local_dir"
done
echo "  Log file        : $LOG_FILE"
echo "  Status command  : bash $INSTALL_DIR/status.sh"
echo
echo "To check status : launchctl list | grep file-transferer"
echo "To view logs    : tail -f \"$LOG_FILE\""
echo "To stop service : launchctl unload \"$PLIST_PATH\""
echo "To uninstall    : bash \"$SCRIPT_DIR/uninstall.sh\""
