#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Daily Capture
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📝
# @raycast.packageName Personal Planning
# @raycast.argument1 { "type": "text", "placeholder": "Quick thought or task" }

# Documentation:
# @raycast.description Append a timestamped entry to today's capture log.
# @raycast.author Alex Chen
# @raycast.authorURL https://github.com/alex-chen-dev

set -euo pipefail

ENTRY="$1"
TIMESTAMP=$(date "+%H:%M")
LOG_DIR="$HOME/Documents/Raycast/Daily-Capture"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).md"

mkdir -p "$LOG_DIR"

if [ ! -s "$LOG_FILE" ]; then
  printf "# %s\n\n" "$(date '+%A, %B %d, %Y')" > "$LOG_FILE"
fi

printf "- [%s] %s\n" "$TIMESTAMP" "$ENTRY" >> "$LOG_FILE"

echo "Captured entry in $LOG_FILE"
