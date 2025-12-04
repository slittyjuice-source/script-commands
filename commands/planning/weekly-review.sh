#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Weekly Review Template
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📅
# @raycast.packageName Personal Planning
# @raycast.description Create or open this week's review note with a guided template.

# Documentation:
# @raycast.author Alex Chen
# @raycast.authorURL https://github.com/alex-chen-dev

set -euo pipefail

REVIEW_DIR="$HOME/Documents/Raycast/Weekly-Reviews"
REVIEW_FILE="$REVIEW_DIR/$(date +%G-W%V).md"

mkdir -p "$REVIEW_DIR"

if [ ! -f "$REVIEW_FILE" ]; then
  WEEK_RANGE=$(ruby -rdate -e "d = Date.today; monday = d - ((d.wday + 6) % 7); sunday = monday + 6; puts \"#{monday.strftime('%b %d')} - #{sunday.strftime('%b %d, %Y')}\"")
  cat > "$REVIEW_FILE" <<TEMPLATE
# Weekly Review ($(date +%G-W%V))

**Week:** $WEEK_RANGE

## Highlights
- 
- 

## Challenges
- 
- 

## Learnings
- 
- 

## Priorities for Next Week
- 
- 
TEMPLATE
fi

open "$REVIEW_FILE"

echo "Opened $REVIEW_FILE"
