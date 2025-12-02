#!/bin/bash

# Dependency: This script requires Python 3 installed
# Install via Homebrew: `brew install python`

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Progress Summary
# @raycast.mode inline
# @raycast.refreshTime 15m
# @raycast.packageName Dashboard

# Optional parameters:
# @raycast.icon 📊
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Show a quick progress summary from a local JSON file.
# @raycast.author OpenAI Assistant
# @raycast.authorURL https://openai.com

set -euo pipefail

CONFIG_PATH="${PROGRESS_SUMMARY_FILE:-$HOME/.config/raycast/progress-summary.json}"
PERIOD_DEFAULT="${PROGRESS_SUMMARY_PERIOD:-this week}"
COLORIZE="${PROGRESS_SUMMARY_COLORIZE:-false}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run this script."
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "No progress data found."
  echo "Create ${CONFIG_PATH} with JSON like {\"period\": \"this week\", \"entries\": [{\"name\": \"Python\", \"hours\": 3}]}"
  exit 0
fi

export CONFIG_PATH
export PERIOD_DEFAULT
export COLORIZE

python3 <<'PY'
import json
import os
import sys
from typing import Iterable, Tuple

path = os.environ["CONFIG_PATH"]
period_default = os.environ.get("PERIOD_DEFAULT", "this week")
colorize = os.environ.get("COLORIZE", "false").lower() == "true"

try:
    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
except Exception as exc:  # pragma: no cover - defensive guard for invalid files
    print(f"Failed to read {path}: {exc}")
    sys.exit(1)

period = period_default
entries: Iterable[dict] = []

if isinstance(payload, dict):
    period = payload.get("period", period_default) or period_default
    entries = payload.get("entries", [])
elif isinstance(payload, list):
    entries = payload
else:
    print("Invalid progress data. Expected an object or array.")
    sys.exit(1)

cleaned: list[Tuple[str, float]] = []
for item in entries:
    if not isinstance(item, dict):
        continue
    name = str(item.get("name", "")).strip()
    if not name:
        continue
    hours_value = item.get("hours", 0)
    try:
        hours = float(hours_value)
    except (TypeError, ValueError):
        continue
    cleaned.append((name, hours))

if not cleaned:
    print("No tracked work.")
    sys.exit(0)

cleaned.sort(key=lambda pair: pair[1], reverse=True)


def format_hours(value: float) -> str:
    text = f"{value:.1f}"
    return text.rstrip("0").rstrip(".")


summary_parts = [f"{name}: {format_hours(hours)}h" for name, hours in cleaned[:3]]
period_suffix = f" ({period})" if period else ""
print("; ".join(summary_parts) + period_suffix)

if colorize:
    GREEN = "\033[32m"
    MUTED = "\033[90m"
    RESET = "\033[0m"

    for name, hours in cleaned:
        color = GREEN if hours > 0 else MUTED
        print(f"{color}{name}: {format_hours(hours)}h{RESET}")
else:
    for name, hours in cleaned:
        print(f"{name}: {format_hours(hours)}h")
PY
