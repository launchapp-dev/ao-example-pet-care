#!/usr/bin/env bash
# calculate-weekly.sh — Aggregate the last 7 days of health logs into weekly metrics.
# Archives previous metrics to data/history/ and writes fresh data/progress-metrics.json.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HEALTH_LOG="$PROJECT_ROOT/data/health-log.json"
MED_LOG="$PROJECT_ROOT/data/medication-log.json"
MED_SCHEDULE="$PROJECT_ROOT/data/medication-schedule.json"
METRICS_OUT="$PROJECT_ROOT/data/progress-metrics.json"
HISTORY_DIR="$PROJECT_ROOT/data/history"

mkdir -p "$HISTORY_DIR"

echo "Calculating weekly metrics..."

# Archive previous metrics if they exist
if [ -f "$METRICS_OUT" ]; then
  PREV_DATE=$(python3 -c "import json; d=json.load(open('$METRICS_OUT')); print(d.get('week_start','unknown'))")
  cp "$METRICS_OUT" "$HISTORY_DIR/weekly-metrics-$PREV_DATE.json"
  echo "  Archived previous metrics to history/weekly-metrics-$PREV_DATE.json"
fi

python3 << 'PYEOF'
import json
import os
from pathlib import Path
from datetime import datetime, timedelta, date

project_root = Path(os.environ.get('PROJECT_ROOT', Path(__file__).parent.parent))
health_log_path = project_root / 'data' / 'health-log.json'
med_log_path = project_root / 'data' / 'medication-log.json'
med_schedule_path = project_root / 'data' / 'medication-schedule.json'
metrics_out_path = project_root / 'data' / 'progress-metrics.json'

today = date.today()
week_start = today - timedelta(days=6)

print(f"  Week: {week_start} to {today}")

# Load health log
with open(health_log_path) as f:
    health_log = json.load(f)

# Filter to last 7 days
week_entries = [
    e for e in health_log
    if week_start <= date.fromisoformat(e['date']) <= today
]

# Get unique pet IDs
pet_ids = list(dict.fromkeys(e['pet_id'] for e in week_entries))

# Load medication data
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
    pet_entries = [e for e in week_entries if e['pet_id'] == pet_id]
    days_tracked = len(pet_entries)

    weights = [e['weight_kg'] for e in pet_entries if e.get('weight_kg')]
    temps = [e['temperature_f'] for e in pet_entries if e.get('temperature_f')]
    appetites = [e['appetite'] for e in pet_entries if e.get('appetite')]
    energies = [e['energy'] for e in pet_entries if e.get('energy')]

    all_symptoms = []
    symptom_days = 0
    for e in pet_entries:
        if e.get('symptoms'):
            all_symptoms.extend(e['symptoms'])
            symptom_days += 1
    unique_symptoms = list(dict.fromkeys(all_symptoms))

    # Medication metrics for this week
    week_med_entries = [
        m for m in med_log
        if m['pet_id'] == pet_id and
        week_start <= date.fromisoformat(m['time_administered'][:10] if m.get('time_administered') else '2000-01-01') <= today
    ]
    # Count scheduled doses this week from medication-schedule
    active_schedules = [s for s in med_schedule if s['pet_id'] == pet_id]
    total_due = 0
    for sched in active_schedules:
        sched_start = date.fromisoformat(sched['start_date'])
        sched_end = date.fromisoformat(sched['end_date'])
        effective_start = max(sched_start, week_start)
        effective_end = min(sched_end, today)
        if effective_start <= effective_end:
            if sched['frequency'] == 'once_daily':
                total_due += (effective_end - effective_start).days + 1
            elif sched['frequency'] == 'twice_daily':
                total_due += ((effective_end - effective_start).days + 1) * 2

    administered = len([m for m in week_med_entries if m.get('status') == 'administered'])
    adherence = round(administered / total_due * 100, 1) if total_due > 0 else None

    pet_metrics.append({
        'pet_id': pet_id,
        'days_tracked': days_tracked,
        'weight_avg_kg': round(sum(weights) / len(weights), 2) if weights else None,
        'weight_min_kg': min(weights) if weights else None,
        'weight_max_kg': max(weights) if weights else None,
        'temperature_avg_f': round(sum(temps) / len(temps), 1) if temps else None,
        'appetite_avg': round(sum(appetites) / len(appetites), 2) if appetites else None,
        'energy_avg': round(sum(energies) / len(energies), 2) if energies else None,
        'symptom_days': symptom_days,
        'unique_symptoms': unique_symptoms,
        'total_medications_due': total_due,
        'total_medications_administered': administered,
        'adherence_rate_pct': adherence,
        'vet_visits': 0,
    })
    print(f"  {pet_id}: {days_tracked} days, avg weight {pet_metrics[-1]['weight_avg_kg']}kg, "
          f"adherence {adherence}%")

metrics = {
    'generated_at': datetime.now().isoformat(),
    'week_start': str(week_start),
    'week_end': str(today),
    'pets': pet_metrics,
}

with open(metrics_out_path, 'w') as f:
    json.dump(metrics, f, indent=2)

print(f"\nWeekly metrics written to data/progress-metrics.json")
PYEOF

export PROJECT_ROOT
