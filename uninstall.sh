#!/usr/bin/env bash
# =============================================================================
# File Transferer — Uninstaller
# Stops the service and removes all installed components.
# Local transfer directories are preserved.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_LABEL="com.$(whoami).file-transferer"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

echo "=== File Transferer — Uninstaller ==="
echo

source "$SCRIPT_DIR/config.sh"

# Stop and remove launchd service
if [ -f "$PLIST_PATH" ]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null && echo "Service stopped." || echo "Service was not running."
    rm -f "$PLIST_PATH"
    echo "Plist removed: $PLIST_PATH"
else
    echo "No plist found (service was not installed)."
fi

# Remove password from Keychain
if security delete-generic-password -a "$REMOTE_USER" -s "file-transferer" 2>/dev/null; then
    echo "Password removed from Keychain."
else
    echo "No Keychain entry found."
fi

# Remove lock files
rm -rf /tmp/file-transferer-locks
echo "Lock files removed."

echo
echo "Done. Your local transfer directories were not removed:"
echo "  $LOCAL_MOVIES_DIR"
echo "  $LOCAL_TV_DIR"
echo
echo "Remove them manually if you no longer need them."
