# Learning Tracker Raycast Commands

A set of Raycast scripts to maintain a goal hierarchy, log time, capture micro-journals, and generate adaptive scheduling suggestions using a local JSON file (`~/.raycast-learning-tracker.json`). Scripts run in a non-login shell and rely on the system Python available on macOS.

## Commands

### Update Goal Hierarchy (`manage-goal-hierarchy.sh`)
- **Title:** Update Goal Hierarchy  
- **Description:** Create or update a goal and its parent relationship. Missing parents are auto-created.  
- **Arguments:**
  1. Goal title (required)
  2. Parent goal (optional)
  3. Priority 1-5 (optional, default 3)
  4. Description (optional)

### Log Time & Surface Neglected Goals (`log-time-and-neglected-goals.sh`)
- **Title:** Log Time & Surface Neglected Goals  
- **Description:** Log minutes spent for a goal and list goals without activity in the chosen lookback window.  
- **Arguments:**
  1. Goal title (required)
  2. Minutes spent (required)
  3. Lookback days (optional, default 7)

### Capture Micro-Journal & Weekly Review (`capture-journal-and-review.sh`)
- **Title:** Capture Micro-Journal & Weekly Review  
- **Description:** Store a dated micro-journal entry with optional tags. On Sundays, shows weekly review prompts.  
- **Arguments:**
  1. Entry or reflection (required)
  2. Tags (comma separated, optional)

### Adaptive Scheduling Suggestions (`adaptive-scheduling-suggestions.sh`)
- **Title:** Adaptive Scheduling Suggestions  
- **Description:** Propose time blocks for the next few days based on recent minutes and priority, highlighting neglected goals.  
- **Arguments:**
  1. Day horizon (optional, default 7)

## Data file
- Stored at `~/.raycast-learning-tracker.json`.
- Structure includes `goals`, `timeLogs`, and `journal` arrays. Files are created automatically on first run.

## Usage notes
- Each command is tagged with `@raycast.packageName Learning Tracker` and includes icon/metadata for discoverability.
- Works offline and avoids login-shell-only features; if you need to reset data, delete `~/.raycast-learning-tracker.json`.
