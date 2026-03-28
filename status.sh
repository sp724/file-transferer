#!/usr/bin/env bash
# =============================================================================
# File Transferer — Status
# Shows active transfers, today's stats, and recent log entries.
# Usage: bash ~/.file-transferer/status.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

LOCK_DIR="/tmp/file-transferer-locks"
TODAY=$(date '+%Y-%m-%d')

echo "=== File Transferer — Status ==="
echo

# -----------------------------------------------------------------------------
# Active transfers (lock files = in-flight)
# -----------------------------------------------------------------------------
active=0
if [[ -d "$LOCK_DIR" ]]; then
    active=$(find "$LOCK_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')
fi
echo "Active transfers : $active"
echo

# -----------------------------------------------------------------------------
# Today's stats from the log
# -----------------------------------------------------------------------------
if [[ -f "$LOG_FILE" ]]; then
    completed=$(grep "\[$TODAY.*Transfer complete" "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
    failed=$(grep "\[$TODAY.*Transfer failed" "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
    echo "Today ($TODAY)"
    echo "  Completed : $completed"
    echo "  Failed    : $failed"
    echo
    echo "--- Last 10 log entries ---"
    tail -n 10 "$LOG_FILE"
else
    echo "Log file not found: $LOG_FILE"
fi
