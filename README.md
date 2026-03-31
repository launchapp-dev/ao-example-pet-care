# Pet Health & Veterinary Pipeline

Automated pet health management for multi-pet households — tracks daily vitals, manages medication schedules, coordinates vet appointments and vaccination calendars, analyzes health trends, and generates comprehensive wellness reports.

---

## Workflow Diagram

```
                    ┌─────────────────────────────────────────────────────┐
                    │              ONBOARD-PET (one-time)                  │
                    │                                                       │
                    │  register-pet → setup-vaccinations → setup-medications│
                    │     └─→ baseline-analysis → compile-onboarding-report │
                    └─────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────────────────────┐
                    │         DAILY-CHECK (every day at 7:00 AM)          │
                    │                                                       │
                    │  log-vitals (script)                                  │
                    │      ↓                                                │
                    │  check-medications                                    │
                    │      ↓                                                │
                    │  assess-health ──────────────────┐                   │
                    │      │ healthy/monitor            │ vet-visit         │
                    │      ↓                            ↓                   │
                    │  daily-summary    ←── schedule-vet                   │
                    └─────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────────────────────┐
                    │       WEEKLY-REVIEW (every Monday at 8:00 AM)       │
                    │                                                       │
                    │  calculate-weekly-metrics (script)                   │
                    │      ↓                                                │
                    │  analyze-trends ─────────────────────────────────┐   │
                    │      ↓                                            │   │
                    │  review-vaccinations                              │   │
                    │      ↓                                            │   │
                    │  update-medications                               │   │
                    │      ↓                                            │   │
                    │  compile-weekly-report ←──────────────────────────┘  │
                    └─────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────────────────────┐
                    │     ANNUAL-WELLNESS (January 1st at 9:00 AM)        │
                    │                                                       │
                    │  calculate-annual-metrics (script)                   │
                    │      ↓                                                │
                    │  comprehensive-evaluation                             │
                    │      │ thriving/stable/declining/senior-transition    │
                    │      ↓ (all routes to plan-care-updates)              │
                    │  plan-care-updates                                    │
                    │      ↓                                                │
                    │  compile-annual-report                                │
                    └─────────────────────────────────────────────────────┘
```

---

## Sample Pets

This example comes pre-configured with two sample pets:

| Pet | Species | Breed | Age | Notable |
|-----|---------|-------|-----|---------|
| **Buddy** | Dog | Golden Retriever | 5 years | Seasonal allergies, mild hip dysplasia. On Apoquel during spring/fall. |
| **Luna** | Cat | Domestic Shorthair | 3 years | Healthy indoor cat. No current conditions. |

---

## Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `onboard-pet` | Manual | Register a new pet, set up vaccinations and medications, establish health baseline |
| `daily-check` | 7:00 AM daily | Log vitals, check medications, assess health, schedule vet if needed |
| `weekly-review` | Monday 8:00 AM | Trend analysis, vaccination review, medication review, weekly report |
| `annual-wellness` | Jan 1st 9:00 AM | Comprehensive annual evaluation, care plan for coming year |

---

## Agents

| Agent | Model | Role |
|-------|-------|------|
| **health-tracker** | claude-sonnet-4-6 | Records vitals from daily-input.yaml, evaluates health status (healthy/monitor/vet-visit), flags urgent concerns |
| **medication-manager** | claude-haiku-4-5 | Tracks medication schedules, logs administered doses, checks interactions and refill dates |
| **appointment-coordinator** | claude-sonnet-4-6 | Manages vaccination calendar, schedules vet visits, tracks upcoming due dates |
| **trend-analyzer** | claude-opus-4-6 | Deep health trend analysis using sequential-thinking — weight curves, symptom patterns, annual evaluations |
| **reporter** | claude-haiku-4-5 | Compiles daily summaries, weekly reports, and annual wellness evaluations into readable Markdown |

---

## AO Features Demonstrated

| Feature | Where |
|---------|-------|
| **Scheduled workflows** | Daily check (7am), weekly review (Mon 8am), annual wellness (Jan 1) |
| **Multi-agent pipeline** | 5 agents with distinct models and roles |
| **Decision contracts** | `assess-health` (healthy/monitor/vet-visit), `comprehensive-evaluation` (thriving/stable/declining/senior-transition) |
| **Phase routing** | Health concern escalates to vet scheduling; all annual verdicts route to care updates |
| **Command phases** | `log-vitals.sh`, `calculate-weekly.sh`, `calculate-annual.sh` |
| **Output contracts** | Structured health records, medication logs, trend analysis JSON |
| **Model variety** | Opus for complex reasoning, Sonnet for assessment, Haiku for fast operations |
| **Post-success merge** | Weekly and annual reports auto-merge to main |

---

## Quick Start

```bash
cd examples/pet-care
ao daemon start

# Onboard pets (run once after setup)
ao queue enqueue --title "Onboard Buddy" --workflow-ref onboard-pet

# Or let the scheduled workflows run automatically:
# - daily-check fires every morning at 7am
# - weekly-review fires every Monday at 8am
# - annual-wellness fires every January 1st

# Check status
ao status
ao task list
```

---

## Project Structure

```
examples/pet-care/
├── .ao/workflows/
│   ├── agents.yaml          # 5 agent profiles
│   ├── phases.yaml          # All phase definitions
│   ├── workflows.yaml       # 4 workflow pipelines
│   ├── schedules.yaml       # 3 cron schedules
│   └── mcp-servers.yaml     # filesystem + sequential-thinking
├── config/
│   ├── pets.yaml            # Pet profiles (Buddy & Luna)
│   ├── vaccination-schedule.yaml  # Species-specific protocols
│   └── medication-reference.yaml  # Medication database with interactions
├── data/
│   ├── daily-input.yaml     # Fill in each morning before 7am
│   ├── health-log.json      # Append-only health record (2 weeks seeded)
│   ├── medication-log.json  # Medication administration history
│   ├── medication-schedule.json  # Active medication schedules
│   ├── vaccination-record.json   # Vaccination history per pet
│   ├── appointments.json    # Upcoming and past vet appointments
│   ├── trend-analysis.json  # Latest trend analysis output
│   ├── progress-metrics.json     # Aggregated weekly/annual metrics
│   └── history/             # Archived weekly/annual snapshots
├── reports/                 # Generated reports (daily, weekly, annual)
├── scripts/
│   ├── log-vitals.sh        # Parse daily-input.yaml → health-log.json
│   ├── calculate-weekly.sh  # Aggregate 7-day metrics
│   └── calculate-annual.sh  # Aggregate full-year metrics
├── CLAUDE.md
└── README.md
```

---

## Requirements

**No API keys required** — this example uses only local file operations.

| Dependency | Purpose | Install |
|------------|---------|---------|
| `@modelcontextprotocol/server-filesystem` | File read/write | auto via npx |
| `@modelcontextprotocol/server-sequential-thinking` | Structured reasoning for trend analysis | auto via npx |
| Python 3 | `log-vitals.sh` and metric scripts | `brew install python3` |
| PyYAML | YAML parsing in log-vitals.sh | `pip3 install pyyaml` |

---

## Daily Usage

Each morning before 7am, update `data/daily-input.yaml` with your pets' measurements:

```yaml
date: "2026-04-01"
pets:
  - pet_id: buddy
    weight_kg: 29.5        # Weigh weekly on Mondays
    temperature_f: 101.2
    appetite: 5            # 1-5 scale
    energy: 4              # 1-5 scale
    symptoms: []           # e.g. ["vomiting", "lethargy"]
    notes: "Normal morning."
  - pet_id: luna
    weight_kg: 4.1
    temperature_f: 101.8
    appetite: 4
    energy: 5
    symptoms: []
    notes: ""
```

The `daily-check` workflow runs at 7am, processes the file, assesses health status, and generates a daily report in `reports/`.
