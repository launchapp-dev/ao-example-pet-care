#!/usr/bin/env bash
# calculate-annual.sh — Aggregate full year of health data into annual metrics.
# Archives data and writes comprehensive annual metrics to data/progress-metrics.json.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HEALTH_LOG="$PROJECT_ROOT/data/health-log.json"
MED_LOG="$PROJECT_ROOT/data/medication-log.json"
MED_SCHEDULE="$PROJECT_ROOT/data/medication-schedule.json"
METRICS_OUT="$PROJECT_ROOT/data/progress-metrics.json"
HISTORY_DIR="$PROJECT_ROOT/data/history"

mkdir -p "$HISTORY_DIR"

YEAR=$(date +%Y)
PREV_YEAR=$((YEAR - 1))

echo "Calculating annual metrics for $PREV_YEAR..."

# Archive current metrics
if [ -f "$METRICS_OUT" ]; then
  cp "$METRICS_OUT" "$HISTORY_DIR/annual-metrics-$PREV_YEAR.json"
  echo "  Archived current metrics"
fi

# Archive health log snapshot
if [ -f "$HEALTH_LOG" ]; then
  cp "$HEALTH_LOG" "$HISTORY_DIR/health-log-$PREV_YEAR.json"
  echo "  Archived health log ($PREV_YEAR)"
fi

python3 << 'PYEOF'
import json
import os
from pathlib import Path
from datetime import datetime, date
from collections import defaultdict

project_root = Path(os.environ.get('PROJECT_ROOT', Path(__file__).parent.parent))
health_log_path = project_root / 'data' / 'health-log.json'
med_log_path = project_root / 'data' / 'medication-log.json'
med_schedule_path = project_root / 'data' / 'medication-schedule.json'
metrics_out_path = project_root / 'data' / 'progress-metrics.json'

year = date.today().year - 1  # Previous year
year_start = date(year, 1, 1)
year_end = date(year, 12, 31)

print(f"  Year: {year_start} to {year_end}")

with open(health_log_path) as f:
    health_log = json.load(f)

# Filter to target year
year_entries = [
    e for e in health_log
    if year_start <= date.fromisoformat(e['date']) <= year_end
]

pet_ids = list(dict.fromkeys(e['pet_id'] for e in year_entries))

med_log = []
if med_log_path.exists():
    with open(med_log_path) as f:
        med_log = json.load(f)

med_schedule = []
if med_schedule_path.exists():
    with open(med_schedule_path) as f:
        med_schedule = json.load(f)

pet_metrics = []
for pet_id in pet_ids:
    pet_entries = sorted(
        [e for e in year_entries if e['pet_id'] == pet_id],
        key=lambda e: e['date']
    )

    # Monthly breakdown
    monthly = defaultdict(list)
    for e in pet_entries:
        month = e['date'][:7]  # YYYY-MM
        monthly[month].append(e)

    monthly_summary = {}
    for month, entries in sorted(monthly.items()):
        weights = [e['weight_kg'] for e in entries if e.get('weight_kg')]
        appetites = [e['appetite'] for e in entries if e.get('appetite')]
        energies = [e['energy'] for e in entries if e.get('energy')]
        sick_days = sum(1 for e in entries if e.get('symptoms'))
        monthly_summary[month] = {
            'days_tracked': len(entries),
            'weight_avg_kg': round(sum(weights) / len(weights), 2) if weights else None,
            'appetite_avg': round(sum(appetites) / len(appetites), 2) if appetites else None,
            'energy_avg': round(sum(energies) / len(energies), 2) if energies else None,
            'sick_days': sick_days,
        }

    # Yearly aggregates
    all_weights = [e['weight_kg'] for e in pet_entries if e.get('weight_kg')]
    all_symptoms = []
    for e in pet_entries:
        all_symptoms.extend(e.get('symptoms', []))

    # Medication adherence for the year
    year_med_entries = [
        m for m in med_log
        if m['pet_id'] == pet_id and
        m.get('time_administered') and
        year_start <= date.fromisoformat(m['time_administered'][:10]) <= year_end
    ]
    administered = len([m for m in year_med_entries if m.get('status') == 'administered'])
    missed = len([m for m in year_med_entries if m.get('status') == 'missed'])

    weight_trajectory = None
    if len(all_weights) >= 2:
        weight_change = all_weights[-1] - all_weights[0]
        weight_trajectory = {
            'start_kg': all_weights[0],
            'end_kg': all_weights[-1],
            'change_kg': round(weight_change, 2),
            'change_pct': round(weight_change / all_weights[0] * 100, 1),
        }

    pet_metrics.append({
        'pet_id': pet_id,
        'year': year,
        'total_days_tracked': len(pet_entries),
        'monthly_breakdown': monthly_summary,
        'weight_trajectory': weight_trajectory,
        'total_symptom_days': sum(1 for e in pet_entries if e.get('symptoms')),
        'unique_symptoms': list(dict.fromkeys(all_symptoms)),
        'medications_administered': administered,
        'medications_missed': missed,
        'annual_adherence_rate_pct': round(administered / (administered + missed) * 100, 1) if (administered + missed) > 0 else None,
    })

    print(f"  {pet_id}: {len(pet_entries)} days tracked, adherence: {pet_metrics[-1]['annual_adherence_rate_pct']}%")

metrics = {
    'generated_at': datetime.now().isoformat(),
    'type': 'annual',
    'year': year,
    'year_start': str(year_start),
    'year_end': str(year_end),
    'pets': pet_metrics,
}

with open(metrics_out_path, 'w') as f:
    json.dump(metrics, f, indent=2)

print(f"\nAnnual metrics written to data/progress-metrics.json")
PYEOF

export PROJECT_ROOT
