#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Capture Micro-Journal & Weekly Review
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📓
# @raycast.packageName Learning Tracker
# @raycast.argument1 { "type": "text", "placeholder": "Entry or reflection" }
# @raycast.argument2 { "type": "text", "placeholder": "Tags (comma separated, optional)", "optional": true }

# Documentation:
# @raycast.description Add a dated micro-journal entry and surface weekly review prompts when appropriate.

ENTRY_TEXT="$1"
TAGS_INPUT="$2"

if [ -z "$ENTRY_TEXT" ]; then
  echo "Please provide a journal entry or reflection."
  exit 1
fi

python <<'PY'
import json
import os
from datetime import datetime
from pathlib import Path

DATA_FILE = os.path.expanduser("~/.raycast-learning-tracker.json")

PROMPTS = [
    "What worked this week?",
    "What felt slow or blocked?",
    "Which goal deserves more focus next week?",
    "What habit moved your goals forward?",
]

def ensure_file():
    if not Path(DATA_FILE).exists():
        template = {"goals": [], "timeLogs": [], "journal": []}
        Path(DATA_FILE).write_text(json.dumps(template, indent=2))

def load_data():
    with open(DATA_FILE) as f:
        return json.load(f)

def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)

ensure_file()

data = load_data()
entry = os.environ["ENTRY_TEXT"]
tags_raw = os.environ.get("TAGS_INPUT") or ""
tags = [tag.strip() for tag in tags_raw.split(",") if tag.strip()]
now = datetime.utcnow()
weekday = now.weekday()  # Monday=0

payload = {
    "timestamp": now.isoformat(),
    "entry": entry,
    "tags": tags,
    "isWeeklyReview": weekday == 6,
}

data.setdefault("journal", []).append(payload)
save_data(data)

print("Saved journal entry for", now.date())
if tags:
    print("Tags:", ", ".join(tags))

if weekday == 6:
    print("\nWeekly review prompts:")
    for prompt in PROMPTS:
        print(f"- {prompt}")
else:
    print("\nDaily nudge: jot down one win, one lesson, one next action.")
PY
