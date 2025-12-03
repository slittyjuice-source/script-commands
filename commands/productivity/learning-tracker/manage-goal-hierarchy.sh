#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Update Goal Hierarchy
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🎯
# @raycast.packageName Learning Tracker
# @raycast.argument1 { "type": "text", "placeholder": "Goal title" }
# @raycast.argument2 { "type": "text", "placeholder": "Parent goal (optional)", "optional": true }
# @raycast.argument3 { "type": "text", "placeholder": "Priority 1-5 (optional)", "optional": true }
# @raycast.argument4 { "type": "text", "placeholder": "Description (optional)", "optional": true }

# Documentation:
# @raycast.description Create or update a goal and maintain its hierarchy in the local learning tracker data file.

DATA_FILE="$HOME/.raycast-learning-tracker.json"
GOAL_TITLE="$1"
PARENT_TITLE="$2"
PRIORITY_INPUT="$3"
DESCRIPTION="$4"

if [ -z "$GOAL_TITLE" ]; then
  echo "Please provide a goal title."
  exit 1
fi

python <<'PY'
import json
import os
import re
from datetime import datetime
from pathlib import Path

DATA_FILE = os.path.expanduser("~/.raycast-learning-tracker.json")

def ensure_file():
    if not Path(DATA_FILE).exists():
        template = {"goals": [], "timeLogs": [], "journal": []}
        Path(DATA_FILE).write_text(json.dumps(template, indent=2))

def slugify(text: str) -> str:
    text = text.strip().lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-") or "goal"

def load_data():
    with open(DATA_FILE) as f:
        return json.load(f)

def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)

ensure_file()
data = load_data()

goal_title = os.environ.get("GOAL_TITLE")
parent_title = os.environ.get("PARENT_TITLE") or ""
priority_input = os.environ.get("PRIORITY_INPUT") or "3"
description = os.environ.get("DESCRIPTION") or ""

try:
    priority = int(priority_input)
    if priority < 1 or priority > 5:
        priority = 3
except ValueError:
    priority = 3

parent_id = slugify(parent_title) if parent_title else None
if parent_title and not any(g.get("id") == parent_id or g.get("title") == parent_title for g in data.get("goals", [])):
    data.setdefault("goals", []).append({
        "id": parent_id,
        "title": parent_title,
        "parent": None,
        "priority": 3,
        "description": "Auto-created parent",
        "updatedAt": datetime.utcnow().isoformat()
    })

goal_id = slugify(goal_title)
existing = None
for g in data.get("goals", []):
    if g.get("id") == goal_id or g.get("title") == goal_title:
        existing = g
        break

if existing:
    existing.update({
        "id": goal_id,
        "title": goal_title,
        "parent": parent_id,
        "priority": priority,
        "description": description,
        "updatedAt": datetime.utcnow().isoformat()
    })
    action = "Updated"
else:
    data.setdefault("goals", []).append({
        "id": goal_id,
        "title": goal_title,
        "parent": parent_id,
        "priority": priority,
        "description": description,
        "updatedAt": datetime.utcnow().isoformat()
    })
    action = "Created"

def format_tree(goals):
    by_parent = {}
    for g in goals:
        by_parent.setdefault(g.get("parent"), []).append(g)
    for children in by_parent.values():
        children.sort(key=lambda x: (x.get("priority", 3), x.get("title", "")))

    lines = []
    def walk(parent_id: str, depth: int = 0):
        for child in by_parent.get(parent_id, []):
            indent = "  " * depth
            lines.append(f"{indent}- {child['title']} (p{child.get('priority', 3)})")
            walk(child.get("id"), depth + 1)
    walk(None)
    return "\n".join(lines) if lines else "(no goals yet)"

save_data(data)

print(f"{action} goal: {goal_title} (priority {priority})")
if parent_title:
    print(f"Parent: {parent_title}")
if description:
    print(f"Description: {description}")
print("\nCurrent hierarchy:\n" + format_tree(data.get("goals", [])))
PY
