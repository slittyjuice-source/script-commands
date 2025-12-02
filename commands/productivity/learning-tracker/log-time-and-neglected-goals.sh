#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Log Time & Surface Neglected Goals
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon ⏱️
# @raycast.packageName Learning Tracker
# @raycast.argument1 { "type": "text", "placeholder": "Goal title" }
# @raycast.argument2 { "type": "text", "placeholder": "Minutes spent" }
# @raycast.argument3 { "type": "text", "placeholder": "Lookback days (optional)", "optional": true }

# Documentation:
# @raycast.description Log time for a goal, then highlight goals without recent attention.

DATA_FILE="$HOME/.raycast-learning-tracker.json"
GOAL_TITLE="$1"
MINUTES_INPUT="$2"
LOOKBACK_INPUT="$3"

if [ -z "$GOAL_TITLE" ] || [ -z "$MINUTES_INPUT" ]; then
  echo "Usage: provide goal title and minutes spent."
  exit 1
fi

python <<'PY'
import json
import os
import re
from datetime import datetime, timedelta
from pathlib import Path

DATA_FILE = os.path.expanduser("~/.raycast-learning-tracker.json")

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

def slugify(text: str) -> str:
    text = text.strip().lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-") or "goal"

ensure_file()

goal_title = os.environ["GOAL_TITLE"]
minutes_input = os.environ["MINUTES_INPUT"]
lookback_input = os.environ.get("LOOKBACK_INPUT") or "7"

try:
    minutes = int(float(minutes_input))
except ValueError:
    minutes = 0

try:
    lookback_days = int(lookback_input)
    if lookback_days <= 0:
        lookback_days = 7
except ValueError:
    lookback_days = 7

data = load_data()
goal_id = slugify(goal_title)

# Make sure goal exists
if not any(g.get("id") == goal_id or g.get("title") == goal_title for g in data.get("goals", [])):
    data.setdefault("goals", []).append({
        "id": goal_id,
        "title": goal_title,
        "parent": None,
        "priority": 3,
        "description": "Auto-created during logging",
        "updatedAt": datetime.utcnow().isoformat()
    })

if minutes > 0:
    data.setdefault("timeLogs", []).append({
        "goalId": goal_id,
        "title": goal_title,
        "minutes": minutes,
        "timestamp": datetime.utcnow().isoformat()
    })
    save_data(data)

def summarize_week(data, since):
    totals = {}
    for log in data.get("timeLogs", []):
        ts = datetime.fromisoformat(log.get("timestamp"))
        if ts >= since:
            totals[log.get("goalId")] = totals.get(log.get("goalId"), 0) + log.get("minutes", 0)
    return totals

def neglected_goals(data, since):
    latest_touch = {}
    for log in data.get("timeLogs", []):
        goal_id = log.get("goalId")
        ts = datetime.fromisoformat(log.get("timestamp"))
        latest_touch[goal_id] = max(latest_touch.get(goal_id, ts), ts)
    neglected = []
    for goal in data.get("goals", []):
        last = latest_touch.get(goal.get("id"))
        if not last or last < since:
            neglected.append(goal)
    return sorted(neglected, key=lambda g: (-g.get("priority", 3), g.get("title", "")))

now = datetime.utcnow()
lookback_start = now - timedelta(days=lookback_days)
week_start = now - timedelta(days=7)
week_totals = summarize_week(data, week_start)

print(f"Logged {minutes} minutes for: {goal_title}\n")
print("Time this week:")
if week_totals:
    for goal in sorted(data.get("goals", []), key=lambda g: g.get("title", "")):
        gid = goal.get("id")
        mins = week_totals.get(gid, 0)
        if mins:
            print(f"- {goal['title']}: {mins} min")
else:
    print("(no time logged yet this week)")

print(f"\nNeglected in the last {lookback_days} day(s):")
for goal in neglected_goals(data, lookback_start):
    print(f"- {goal['title']} (priority {goal.get('priority', 3)})")
PY
