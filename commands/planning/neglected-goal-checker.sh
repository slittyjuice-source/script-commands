#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Neglected Goal Checker
# @raycast.mode inline

# Optional parameters:
# @raycast.icon 🎯
# @raycast.packageName Personal Planning
# @raycast.argument1 { "type": "text", "placeholder": "Goals directory (optional)", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Days stale (default: 14)", "optional": true }

# Documentation:
# @raycast.description List goal files that haven't been updated recently.
# @raycast.author Alex Chen
# @raycast.authorURL https://github.com/alex-chen-dev

set -euo pipefail

goals_dir=${1:-"$HOME/Documents/Goals"}
stale_days=${2:-14}

if ! [[ "$stale_days" =~ ^[0-9]+$ ]]; then
  echo "Days stale must be a non-negative integer." >&2
  exit 1
fi

mkdir -p "$goals_dir"

stale_files=()
while IFS= read -r -d '' file; do
  stale_files+=("$file")
done < <(find "$goals_dir" -maxdepth 1 -type f -mtime +"$stale_days" -print0)

if [ ${#stale_files[@]} -eq 0 ]; then
  echo "All goals have been updated within the last $stale_days days."
  exit 0
fi

echo "Goals not updated in $stale_days days:"
for file in "${stale_files[@]}"; do
  relative_path=${file#"$HOME"/}
  last_touch=$(date -r "$file" "+%Y-%m-%d")
  echo "- $relative_path (last updated $last_touch)"
done
