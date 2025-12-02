#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Adaptive Scheduling Suggestions
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🗓️
# @raycast.packageName Learning Tracker
# @raycast.argument1 { "type": "text", "placeholder": "Day horizon (days, optional)", "optional": true }

# Documentation:
# @raycast.description Propose a focused schedule based on recent progress and neglected goals.

HORIZON_INPUT="$1"

python <<'PY'
import json
import os
from collections import defaultdict
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

ensure_file()

data = load_data()
raw_horizon = os.environ.get("HORIZON_INPUT") or "7"
try:
    horizon_days = int(raw_horizon)
    if horizon_days <= 0:
        horizon_days = 7
except ValueError:
    horizon_days = 7

now = datetime.utcnow()
lookback = now - timedelta(days=horizon_days)

recent = defaultdict(int)
latest_touch = {}
for log in data.get("timeLogs", []):
    ts = datetime.fromisoformat(log.get("timestamp"))
    gid = log.get("goalId")
    if ts >= lookback:
        recent[gid] += log.get("minutes", 0)
    latest_touch[gid] = max(latest_touch.get(gid, ts), ts)

ranked_goals = sorted(data.get("goals", []), key=lambda g: (-g.get("priority", 3), g.get("title", "")))

print(f"Adaptive focus for the next {horizon_days} day(s):\n")
for goal in ranked_goals:
    gid = goal.get("id")
    minutes = recent.get(gid, 0)
    last = latest_touch.get(gid)
    status = "✅ on track" if minutes >= 90 else "⚠️ light" if minutes > 0 else "❗ neglected"
    print(f"- {goal['title']} (p{goal.get('priority', 3)}): {minutes} min recent — {status}")

suggestions = []
for goal in ranked_goals:
    gid = goal.get("id")
    minutes = recent.get(gid, 0)
    if minutes < 60:
        suggestions.append((goal, max(30, (60 - minutes))))
    elif minutes < 150:
        suggestions.append((goal, 45))

print("\nSuggested schedule blocks:")
if suggestions:
    for goal, block in suggestions[:6]:
        print(f"• {goal['title']}: {block} min (priority {goal.get('priority', 3)})")
else:
    print("Looks balanced—use the time for consolidation or learning sprints.")

neglected = [g for g in ranked_goals if g.get("id") not in latest_touch]
if neglected:
    print("\nBring these onto the calendar:")
    for goal in neglected:
        print(f"• {goal['title']} (no recent time) — schedule 20 min primer")
PY
