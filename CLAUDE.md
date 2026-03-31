# Pet Health & Veterinary Pipeline — Agent Context

This is an automated pet health management system. You are an AI agent working within
the AO workflow framework to help manage the health of a multi-pet household.

## Pets in This Household

| ID | Name | Species | Breed | Age | Active Medications |
|----|------|---------|-------|-----|--------------------|
| buddy | Buddy | Dog | Golden Retriever | 5 years | Apoquel 16mg (seasonal allergies) |
| luna | Luna | Cat | Domestic Shorthair | 3 years | None |

Full profiles: `config/pets.yaml`

## Your Role (by agent)

- **health-tracker**: You assess daily health data from `data/daily-input.yaml` and `data/health-log.json`.
  Your health assessments drive routing decisions — be conservative. When in doubt, escalate.
- **medication-manager**: You manage `data/medication-schedule.json` and `data/medication-log.json`.
  Precision matters — always verify doses against weight guidelines in `config/medication-reference.yaml`.
- **appointment-coordinator**: You manage `data/vaccination-record.json` and `data/appointments.json`.
  Use `config/vaccination-schedule.yaml` for species-specific protocols.
- **trend-analyzer**: You perform deep analysis on health data trends. Use sequential-thinking for complex
  assessments. Write results to `data/trend-analysis.json`.
- **reporter**: You generate human-readable reports to the `reports/` directory. Write for pet owners,
  not veterinarians — clear, specific, actionable.

## Data File Conventions

- `data/health-log.json` — append-only. Never delete or modify existing entries.
- `data/medication-log.json` — append-only. Add new dose records; never modify past records.
- `data/vaccination-record.json` — update next_due dates when vaccines are administered.
- `data/appointments.json` — append new appointments; update status field for existing ones.
- `data/trend-analysis.json` — overwrite with latest analysis (not append-only).
- `data/progress-metrics.json` — overwrite with latest metrics (not append-only).

## Report Naming Conventions

| Report Type | Filename Pattern | Example |
|-------------|-----------------|---------|
| Daily summary | `reports/daily-YYYY-MM-DD.md` | `reports/daily-2026-03-31.md` |
| Weekly report | `reports/weekly-YYYY-MM-DD.md` | `reports/weekly-2026-03-30.md` |
| Onboarding | `reports/onboarding-<pet_name>.md` | `reports/onboarding-buddy.md` |
| Annual | `reports/annual-YYYY-<pet_name>.md` | `reports/annual-2026-buddy.md` |

## Health Assessment Thresholds

**Dogs (Buddy)**
- Temperature: 99.0–102.5°F normal; <99°F or >103°F → vet-visit
- Weight change: >3% from baseline in 7 days → flag; >5% → vet-visit
- Appetite: <3 for 2+ consecutive days → monitor; <2 → vet-visit

**Cats (Luna)**
- Temperature: 100.0–102.5°F normal; <100°F or >103°F → vet-visit
- Weight change: >2% from baseline in 7 days → flag; >5% → vet-visit
- Appetite: <3 for 2+ consecutive days → monitor; <2 → vet-visit

## Medication Reference

Buddy's Apoquel (oclacitinib):
- Standard dose: 0.4 mg/kg. At 29.5kg → 11.8mg min / 23.6mg max daily
- Current dose: 16mg (0.54 mg/kg) — within therapeutic range
- Seasonal schedule: March 1 – May 31 (spring allergies), September 1 – October 31 (fall allergies)
- Side effect watch: increased infections, GI upset, lethargy

## Important Notes

- Never modify `config/pets.yaml` unless explicitly onboarding a new pet
- Never modify `config/vaccination-schedule.yaml` or `config/medication-reference.yaml` — these are reference files
- Appointment dates should be business days (Mon-Fri)
- Use ISO 8601 format for all dates: YYYY-MM-DD
- All weights in kg, temperatures in Fahrenheit
