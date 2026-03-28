#!/usr/bin/env bash
# =============================================================================
# File Transferer — Watcher Daemon
# Watches local drop folders and SCP-transfers files to the remote server.
# Managed by launchd; do not run directly in production.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

LOCK_DIR="/tmp/file-transferer-locks"
mkdir -p "$LOCK_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# macOS notification
# -----------------------------------------------------------------------------
notify() {
    local title="$1"
    local message="$2"
    terminal-notifier -title "$title" -message "$message" -sender com.apple.Terminal 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Human-readable file size using awk (no external deps)
# -----------------------------------------------------------------------------
format_size() {
    local bytes=$1
    if ((bytes >= 1073741824)); then
        awk "BEGIN {printf \"%.1f GB\", $bytes/1073741824}"
    elif ((bytes >= 1048576)); then
        awk "BEGIN {printf \"%.1f MB\", $bytes/1048576}"
    else
        awk "BEGIN {printf \"%.0f KB\", $bytes/1024}"
    fi
}

# -----------------------------------------------------------------------------
# Block until the file is fully written.
# Strategy: poll lsof (checks for open handles) AND file size stability.
# -----------------------------------------------------------------------------
wait_for_completion() {
    local file="$1"
    local prev_size=-1
    local stable=0

    while true; do
        # If any process still has the file open, reset and wait
        if lsof "$file" > /dev/null 2>&1; then
            stable=0
            sleep "$STABILITY_INTERVAL"
            continue
        fi

        local size
        size=$(stat -f%z "$file" 2>/dev/null || echo -1)

        if [[ "$size" == "$prev_size" ]] && [[ "$size" -gt 0 ]]; then
            ((stable++))
            if [[ $stable -ge $STABILITY_CHECKS ]]; then
                return 0
            fi
        else
            stable=0
            prev_size="$size"
        fi

        sleep "$STABILITY_INTERVAL"
    done
}

# -----------------------------------------------------------------------------
# Perform the SCP transfer
# -----------------------------------------------------------------------------
transfer_file() {
    local file="$1"
    local remote_path="$2"
    local name
    name="$(basename "$file")"
    local size
    size=$(stat -f%z "$file" 2>/dev/null || echo 0)

    log "INFO" "Transfer start: $name ($(format_size "$size")) -> ${REMOTE_HOST}:${remote_path}/"

    local password
    password=$(security find-generic-password -a "$REMOTE_USER" -s "file-transferer" -w 2>/dev/null) || {
        log "ERROR" "Keychain lookup failed for user '$REMOTE_USER'. Re-run install.sh to update the password."
        return 1
    }

    local error_output
    if error_output=$(sshpass -p "$password" scp \
        -P "$REMOTE_PORT" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=30 \
        "$file" "${REMOTE_USER}@${REMOTE_HOST}:${remote_path}/" 2>&1); then
        log "INFO" "Transfer complete: $name"
        notify "Transfer Complete" "$name"
    else
        local code=$?
        log "ERROR" "Transfer failed: $name (scp exit code $code): $error_output"
        notify "Transfer Failed" "$name — check the log for details"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Returns 0 (true) if the file should be ignored
# -----------------------------------------------------------------------------
is_ignorable() {
    local name
    name="$(basename "$1")"
    # Directories
    [ -d "$1" ] && return 0
    # Hidden files and macOS metadata
    [[ "$name" == .* ]] && return 0
    # Browser/downloader temp extensions
    [[ "$name" == *.crdownload ]] && return 0
    [[ "$name" == *.part ]] && return 0
    [[ "$name" == *.download ]] && return 0
    [[ "$name" == *.tmp ]] && return 0
    [[ "$name" == *.swp ]] && return 0
    return 1
}

# -----------------------------------------------------------------------------
# Handle a new file event: deduplicate, wait for completion, transfer
# -----------------------------------------------------------------------------
handle_new_file() {
    local file="$1"
    local remote_path="$2"

    [ ! -f "$file" ] && return
    is_ignorable "$file" && return

    # Deduplication: use a lock file keyed by the file path hash.
    # The lock is removed after the transfer completes (or fails).
    local lock_key
    lock_key=$(printf '%s' "$file" | shasum | cut -d' ' -f1)
    local lock="$LOCK_DIR/$lock_key"

    [ -f "$lock" ] && return
    touch "$lock"

    local name
    name="$(basename "$file")"
    log "INFO" "Detected: $name"

    # Run wait + transfer in a subshell so the watcher loop is never blocked
    (
        wait_for_completion "$file"
        transfer_file "$file" "$remote_path"
        rm -f "$lock"
    ) &
}

# -----------------------------------------------------------------------------
# Startup
# -----------------------------------------------------------------------------
log "INFO" "------------------------------------------------------------"
log "INFO" "Watcher started"
log "INFO" "  Movies : $LOCAL_MOVIES_DIR -> ${REMOTE_HOST}:${REMOTE_MOVIES_PATH}"
log "INFO" "  TV     : $LOCAL_TV_DIR -> ${REMOTE_HOST}:${REMOTE_TV_PATH}"
log "INFO" "------------------------------------------------------------"

# Watch both directories; -0 uses null-delimited output (safe for any filename)
fswatch -0 -r \
    "$LOCAL_MOVIES_DIR" \
    "$LOCAL_TV_DIR" \
| while IFS= read -r -d '' path; do
    if [[ "$path" == "$LOCAL_MOVIES_DIR"* ]]; then
        handle_new_file "$path" "$REMOTE_MOVIES_PATH"
    elif [[ "$path" == "$LOCAL_TV_DIR"* ]]; then
        handle_new_file "$path" "$REMOTE_TV_PATH"
    fi
done
