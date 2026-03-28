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

# Remote destination paths on your Windows server.
# Use Windows-style drive paths with forward slashes: C:\Users\... becomes c:/Users/...
# Example: "c:/Users/john/Videos/Movies"
REMOTE_MOVIES_PATH="c:/Users/SKP/Documents/Movies"
REMOTE_TV_PATH="c:/Users/SKP/Documents/TVShows"

# -----------------------------------------------------------------------------
# Local watch directories (files dropped here will be transferred)
# -----------------------------------------------------------------------------
LOCAL_MOVIES_DIR="$HOME/Downloads/Transfer/Movies"
LOCAL_TV_DIR="$HOME/Downloads/Transfer/TV"

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
