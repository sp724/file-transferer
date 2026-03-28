#!/usr/bin/env bash
# =============================================================================
# File Transferer — Configuration
# Edit the values below, then run install.sh
# =============================================================================

# Remote server address (IP or hostname)
REMOTE_HOST="10.0.0.250"          # e.g., "192.168.1.100" or "my-windows-pc.local"

# Windows username used for SSH/SCP
REMOTE_USER="sp724"          # e.g., "john"

# SSH port (default is 22)
REMOTE_PORT=22

# -----------------------------------------------------------------------------
# Watch directory pairs
# Each entry maps a local drop folder to a remote destination path.
# Format: "local_path:remote_path"
# Use Windows-style drive paths with forward slashes: C:\Users\... -> c:/Users/...
# Add or remove entries to watch more or fewer folders.
# -----------------------------------------------------------------------------
WATCH_PAIRS=(
    "$HOME/Downloads/Transfer/Movies:c:/Users/SKP/Documents/Movies"
    "$HOME/Downloads/Transfer/TV:c:/Users/SKP/Documents/TVShows"
)

# -----------------------------------------------------------------------------
# Log file
# -----------------------------------------------------------------------------
LOG_FILE="$HOME/Library/Logs/file-transferer.log"

# -----------------------------------------------------------------------------
# File stability settings
# The watcher waits until a file's size has been unchanged for
# (STABILITY_CHECKS × STABILITY_INTERVAL) seconds before transferring.
# Default: 4 checks × 3 seconds = 12 seconds of no change required.
# Increase STABILITY_CHECKS for very large files on slow storage.
# -----------------------------------------------------------------------------
STABILITY_INTERVAL=3    # seconds between size checks
STABILITY_CHECKS=4      # number of consecutive stable checks required

# -----------------------------------------------------------------------------
# Transfer reliability settings
# -----------------------------------------------------------------------------
TRANSFER_MAX_RETRIES=3        # retry attempts after a failed transfer (0 = no retries)
TRANSFER_RETRY_BASE_DELAY=30  # seconds before first retry; doubles each attempt
TRANSFER_TIMEOUT=3600         # max seconds for a single SCP attempt (1 hour)

# -----------------------------------------------------------------------------
# Ignored file extensions (space-separated)
# Files matching these extensions are skipped by the watcher.
# Add your own temp/partial extensions as needed.
# -----------------------------------------------------------------------------
IGNORE_EXTENSIONS=".crdownload .part .download .tmp .swp"
