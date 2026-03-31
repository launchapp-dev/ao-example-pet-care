# Pet Health & Veterinary Pipeline — Workflow Plan

## Overview

An automated pet health management system for multi-pet households. Tracks wellness metrics (weight, vitals, symptoms), manages medication schedules with reminders, coordinates vaccination calendars and vet appointments, analyzes health trends for early intervention, and produces comprehensive wellness reports.

---

## Agents

| Agent | Model | Role |
|---|---|---|
| **health-tracker** | claude-sonnet-4-6 | Records pet vitals, weight, symptoms. Maintains structured health records per pet. Flags immediate concerns. |
| **medication-manager** | claude-haiku-4-5 | Manages medication schedules, tracks doses administered, checks for interactions, generates daily medication reminders. |
| **appointment-coordinator** | claude-sonnet-4-6 | Manages vaccination calendar, schedules vet visits, tracks upcoming due dates, sends appointment summaries. |
| **trend-analyzer** | claude-opus-4-6 | Analyzes health data trends over time — weight curves, vital patterns, symptom recurrence. Flags abnormalities for early intervention. Uses sequential-thinking for complex diagnostic reasoning. |
| **reporter** | claude-haiku-4-5 | Compiles weekly health summaries, monthly wellness reports, and annual comprehensive wellness evaluations per pet. |

## MCP Servers

| Server | Purpose |
|---|---|
| `filesystem` | Read/write all data files, configs, reports |
| `sequential-thinking` | Complex health trend analysis and diagnostic reasoning |

---

## Data Model

| File | What It Contains | Who Reads | Who Writes |
|---|---|---|---|
| `config/pets.yaml` | Pet profiles: name, species, breed, DOB, weight baseline, known conditions, allergies | All agents | Never modified after onboarding (add new pets via onboard workflow) |
| `config/vaccination-schedule.yaml` | Species-specific vaccination protocols: vaccine name, interval, required vs optional | appointment-coordinator, reporter | Static reference |
| `config/medication-reference.yaml` | Common pet medications: dosage guidelines, interaction warnings, administration notes | medication-manager | Static reference |
| `data/health-log.json` | Daily health entries per pet: weight, temperature, appetite (1-5), energy (1-5), symptoms (array), notes | health-tracker, trend-analyzer | health-tracker (append daily) |
| `data/medication-log.json` | Medication records: pet, medication, dose, time administered, next due, status | medication-manager, reporter | medication-manager (append/update) |
| `data/medication-schedule.json` | Active medication schedules per pet: medication, dosage, frequency, start date, end date, refill date | medication-manager, health-tracker | medication-manager |
| `data/vaccination-record.json` | Vaccination history per pet: vaccine, date administered, next due, vet, lot number | appointment-coordinator, reporter | appointment-coordinator |
| `data/appointments.json` | Upcoming and past vet appointments: pet, date, type (wellness/sick/vaccination/dental), vet, notes | appointment-coordinator, reporter | appointment-coordinator |
| `data/trend-analysis.json` | Computed health trends: weight trend, appetite trend, energy trend, symptom frequency, flags | trend-analyzer, reporter | trend-analyzer |
| `data/history/` | Weekly and monthly snapshots for long-term trend analysis | trend-analyzer, reporter | calculate scripts |
| `reports/` | Weekly summaries, monthly reports, annual wellness evaluations | Pet owner reference | reporter |

---

## Workflows

### 1. `onboard-pet` (one-time per pet)

Setup flow when adding a new pet to the system.

**Phases:**
1. **register-pet** (agent: health-tracker) — Read `config/pets.yaml`, validate the new pet profile, establish baseline health metrics, write initial entry to `data/health-log.json`
2. **setup-vaccinations** (agent: appointment-coordinator) — Read pet profile and `config/vaccination-schedule.yaml`, determine which vaccinations are due or upcoming based on species/age/history, write initial `data/vaccination-record.json` entry and schedule upcoming vaccinations in `data/appointments.json`
3. **setup-medications** (agent: medication-manager) — Read pet profile for known conditions, set up any ongoing medication schedules in `data/medication-schedule.json`, check for interactions against `config/medication-reference.yaml`
4. **baseline-analysis** (agent: trend-analyzer) — Read all initial data, establish baseline health profile, note any pre-existing concerns, write initial `data/trend-analysis.json`
5. **compile-onboarding-report** (agent: reporter) — Generate a comprehensive onboarding summary to `reports/onboarding-<pet-name>.md` with pet profile, vaccination plan, medication plan, and baseline health snapshot

**Post-success:** Squash merge to main, create PR, auto-merge.

### 2. `daily-check` (scheduled: every day at 7am)

Daily health monitoring and medication management.

**Phases:**
1. **log-vitals** (command) — `bash scripts/log-vitals.sh` — Reads today's check-in data from `data/daily-input.yaml` (simulated sensor/manual input), appends to `data/health-log.json`
2. **check-medications** (agent: medication-manager) — Read `data/medication-schedule.json` and `data/medication-log.json`. Identify medications due today. Log administered doses. Flag any missed doses. Check if any prescriptions need refill (within 7 days of end date). Return structured status.
3. **assess-health** (agent: health-tracker) — Read today's health log entry and medication status. Evaluate each pet's daily health:
   - **healthy**: all vitals normal, no symptoms → continue monitoring
   - **monitor**: minor symptoms or slight vital deviation → note for trend analysis
   - **vet-visit**: significant symptoms, abnormal vitals, or persistent concern → flag for appointment
   Decision contract with verdict field.
4. **schedule-vet** (agent: appointment-coordinator) — Only reached if assess-health verdict = `vet-visit`. Read the health concern details, check `data/appointments.json` for existing upcoming appointments. If none scheduled, create a new appointment entry. Return appointment details.
5. **daily-summary** (agent: reporter) — Generate brief daily health summary for all pets to `reports/daily-<date>.md`. Include medication status, health verdicts, any new appointments.

**Routing:**
- assess-health `healthy` → daily-summary
- assess-health `monitor` → daily-summary
- assess-health `vet-visit` → schedule-vet → daily-summary

### 3. `weekly-review` (scheduled: every Monday at 8am)

Weekly health trend analysis and comprehensive review.

**Phases:**
1. **calculate-weekly-metrics** (command) — `bash scripts/calculate-weekly.sh` — Aggregate the week's health logs, medication adherence, appointment activity into `data/progress-metrics.json`
2. **analyze-trends** (agent: trend-analyzer) — Read `data/progress-metrics.json`, `data/health-log.json` (last 7 days), `data/history/` for comparison. Analyze per pet:
   - Weight trend (gaining/stable/losing — flag if >5% change in a week)
   - Appetite and energy trends (improving/stable/declining)
   - Symptom recurrence patterns (new, recurring, resolved)
   - Medication adherence rate
   - Overall health trajectory
   Return structured JSON with health status per pet and any flags.
3. **review-vaccinations** (agent: appointment-coordinator) — Read `data/vaccination-record.json`. Check if any vaccinations are due within the next 30 days. Update `data/appointments.json` with vaccination appointments if needed. Return vaccination status per pet:
   - **current**: all vaccinations up to date
   - **due-soon**: vaccination due within 30 days
   - **overdue**: vaccination past due date
4. **update-medications** (agent: medication-manager) — Read `data/medication-schedule.json` and `data/medication-log.json`. Review medication effectiveness based on symptom trends from trend analysis. Flag medications nearing refill date. Check for any dose adjustments needed based on weight changes. Return medication review summary.
5. **compile-weekly-report** (agent: reporter) — Generate weekly wellness report to `reports/weekly-<date>.md`. Include per-pet health summary, trend charts (ASCII), medication adherence, vaccination status, upcoming appointments, and any flags/recommendations.

**Post-success:** Squash merge to main, create PR, auto-merge.

### 4. `annual-wellness` (scheduled: 1st of January at 9am)

Comprehensive annual wellness evaluation.

**Phases:**
1. **calculate-annual-metrics** (command) — `bash scripts/calculate-annual.sh` — Aggregate full year of health data into annual metrics
2. **comprehensive-evaluation** (agent: trend-analyzer) — Deep analysis of each pet's year: weight trajectory, illness frequency, medication changes, vaccination compliance, aging indicators. Use sequential-thinking for complex assessments. Return verdict per pet:
   - **thriving**: excellent health year, continue current care plan
   - **stable**: healthy with minor issues, some adjustments recommended
   - **declining**: concerning trends detected, recommend comprehensive vet exam
   - **senior-transition**: aging indicators suggest transitioning to senior care protocol
3. **plan-care-updates** (agent: appointment-coordinator) — Based on evaluation, schedule annual wellness exams, update vaccination calendar for next year, recommend preventive care. Write updated schedules.
4. **compile-annual-report** (agent: reporter) — Generate comprehensive annual wellness report per pet to `reports/annual-<year>-<pet-name>.md`. Include year-in-review narrative, health metrics over 12 months, vaccination history, medication history, cost summary, and care plan for the next year.

**Post-success:** Squash merge to main, create PR, auto-merge.

---

## Supporting Files

### Scripts

| Script | Purpose |
|---|---|
| `scripts/log-vitals.sh` | Reads `data/daily-input.yaml`, validates entries, appends to `data/health-log.json` with timestamp |
| `scripts/calculate-weekly.sh` | Aggregates 7 days of health logs into weekly metrics, archives to `data/history/` |
| `scripts/calculate-annual.sh` | Aggregates 12 months of data into annual metrics |

### Config Files

| File | Purpose |
|---|---|
| `config/pets.yaml` | Multi-pet household profiles (2 sample pets: a dog and a cat) |
| `config/vaccination-schedule.yaml` | Species-specific vaccination protocols (dog: DHPP, rabies, bordetella; cat: FVRCP, rabies, FeLV) |
| `config/medication-reference.yaml` | Common medications with dosage/weight guidelines and interaction warnings |

### Sample Data

| File | Purpose |
|---|---|
| `data/daily-input.yaml` | Template for daily check-in data (weight, temp, appetite, energy, symptoms) |
| `data/health-log.json` | Pre-seeded with 2 weeks of sample data for both pets |
| `data/medication-schedule.json` | Pre-seeded with sample ongoing medications |
| `data/vaccination-record.json` | Pre-seeded with vaccination history |
| `data/appointments.json` | Pre-seeded with upcoming appointments |

---

## README Outline

1. **What This Is** — Automated pet health management for multi-pet households
2. **What It Does** — Daily health monitoring, medication management, vaccination tracking, trend analysis, wellness reporting
3. **Sample Pets** — Introduce the two sample pets (dog + cat) with their profiles
4. **Workflows** — Table of 4 workflows with cadence and description
5. **Getting Started** — `ao daemon start`, onboard pets, let daily/weekly/annual workflows run
6. **Project Structure** — Directory tree
7. **AO Features Demonstrated** — Scheduled workflows, multi-agent pipeline, decision contracts, phase routing, command phases, output contracts

---

## AO Features Demonstrated

| Feature | Where |
|---|---|
| Scheduled workflows | Daily check (7am), weekly review (Mon 8am), annual wellness (Jan 1 9am) |
| Multi-agent pipeline | 5 specialized agents with distinct roles and model choices |
| Decision contracts | `assess-health` (healthy/monitor/vet-visit), `comprehensive-evaluation` (thriving/stable/declining/senior-transition), vaccination status (current/due-soon/overdue) |
| Output contracts | Structured health records, medication schedules, wellness reports |
| Phase routing | Escalate to vet scheduling on health concern, route annual evaluation to care updates |
| Command phases | Vital logging, weekly/annual metric calculation |
| Rework loops | Not primary here — health decisions are forward-flowing |
| Model variety | Opus for complex trend analysis, Sonnet for health tracking and coordination, Haiku for fast medication checks and reporting |

---

## Directory Structure

```
examples/pet-care/
├── .ao/workflows/
│   ├── agents.yaml
│   ├── phases.yaml
│   ├── workflows.yaml
│   ├── schedules.yaml
│   └── mcp-servers.yaml
├── config/
│   ├── pets.yaml
│   ├── vaccination-schedule.yaml
│   └── medication-reference.yaml
├── data/
│   ├── daily-input.yaml
│   ├── health-log.json
│   ├── medication-log.json
│   ├── medication-schedule.json
│   ├── vaccination-record.json
│   ├── appointments.json
│   ├── trend-analysis.json
│   ├── progress-metrics.json
│   └── history/
├── reports/
├── scripts/
│   ├── log-vitals.sh
│   ├── calculate-weekly.sh
│   └── calculate-annual.sh
├── CLAUDE.md
└── README.md
```
