#!/usr/bin/env bash
# log-vitals.sh — Read daily-input.yaml and append entries to health-log.json
# Runs as a command phase in the daily-check workflow.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DAILY_INPUT="$PROJECT_ROOT/data/daily-input.yaml"
HEALTH_LOG="$PROJECT_ROOT/data/health-log.json"

if [ ! -f "$DAILY_INPUT" ]; then
  echo "ERROR: daily-input.yaml not found at $DAILY_INPUT"
  exit 1
fi

# Extract date from the input file
INPUT_DATE=$(grep "^date:" "$DAILY_INPUT" | sed "s/date: *//;s/\"//g;s/ *$//")

if [ -z "$INPUT_DATE" ]; then
  echo "ERROR: No date found in daily-input.yaml"
  exit 1
fi

echo "Processing daily vitals for date: $INPUT_DATE"

# Check if entries for this date already exist in health-log.json
if [ -f "$HEALTH_LOG" ] && python3 -c "
import json, sys
with open('$HEALTH_LOG') as f:
    log = json.load(f)
dates = [e['date'] for e in log]
sys.exit(0 if '$INPUT_DATE' in dates else 1)
" 2>/dev/null; then
  echo "INFO: Entries for $INPUT_DATE already exist in health-log.json. Skipping."
  exit 0
fi

# Parse daily-input.yaml and append to health-log.json using Python
python3 << 'PYEOF'
import json
import yaml
import sys
import os
from pathlib import Path

project_root = Path(os.environ.get('PROJECT_ROOT', Path(__file__).parent.parent))
daily_input_path = project_root / 'data' / 'daily-input.yaml'
health_log_path = project_root / 'data' / 'health-log.json'

with open(daily_input_path) as f:
    input_data = yaml.safe_load(f)

input_date = input_data.get('date', '')
if not input_date:
    print('ERROR: No date in daily-input.yaml')
    sys.exit(1)

# Load existing log or start empty
if health_log_path.exists():
    with open(health_log_path) as f:
        health_log = json.load(f)
else:
    health_log = []

new_entries = 0
for pet in input_data.get('pets', []):
    entry = {
        'pet_id': pet['pet_id'],
        'date': str(input_date),
        'weight_kg': pet.get('weight_kg'),
        'temperature_f': pet.get('temperature_f'),
        'appetite': pet.get('appetite'),
        'energy': pet.get('energy'),
        'symptoms': pet.get('symptoms', []),
        'notes': pet.get('notes', ''),
    }

    # Validate required fields
    if entry['weight_kg'] is None or entry['temperature_f'] is None:
        print(f"WARNING: Missing weight or temperature for pet {entry['pet_id']}")
        continue

    health_log.append(entry)
    new_entries += 1
    print(f"  Logged: {entry['pet_id']} — weight={entry['weight_kg']}kg, temp={entry['temperature_f']}°F, "
          f"appetite={entry['appetite']}/5, energy={entry['energy']}/5, "
          f"symptoms={entry['symptoms'] or 'none'}")

with open(health_log_path, 'w') as f:
    json.dump(health_log, f, indent=2)

print(f"\nSuccessfully appended {new_entries} entries to health-log.json")
PYEOF

export PROJECT_ROOT
