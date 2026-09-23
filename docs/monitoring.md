# NYC Mobility Pipeline — Production Monitoring

This document describes the pipeline as currently deployed. Work in
progress on improvements is tracked separately and is not reflected
here until merged.

## Quick reference: is the pipeline healthy?

| What to check | Healthy looks like | If not |
|---|---|---|
| Job status | Overall run = SUCCESS | Open the failed task — see `runbook.md` SECTION 2 |
| Task status | Every task in the DAG succeeds | Check that task's log; cross-reference the task matrix in SECTION 2 below |
| Runtime | No baseline established yet — see SECTION 6 | N/A until a baseline exists |
| Retries | 0 unexpected retries on the 6 tasks with retry configured (SECTION 5) | 1–2 retries then success is normal; still failing after 2 retries needs investigating |
| Green Taxi row counts | Not currently checked automatically | No automated check exists today; verify manually if needed |
| DQ results | PASS or an accepted WARN | Not currently enforced — see SECTION 3 and SECTION 4 |
| Gold dimension counts | `dim_datetime`=2,209, `dim_location`=265, `dim_weather`=2,208 | Any mismatch means an upstream Bronze/Silver step under-delivered |
| Analytics tasks | All 3 complete without error | Check Gold table health first — analytics failures are usually downstream symptoms, not the root cause |

## 1. Current freshness meaning

The pipeline loads a fixed historical window: March 1 – May 31, 2026
(2,208 hourly weather observations, 265 taxi zones, ~44k Green Taxi trips
per month). This is not a live/rolling feed. "Freshness" currently means
whether each dataset fully covers this historical period, not how recent
the data is.

## 2. Task monitoring matrix

Based on the DAG in `resources/nyc_mobility_job.yml`:

| Task key | Layer | What to check | Failure impact |
|---|---|---|---|
| `init_schemas` | Setup | Task success | Whole pipeline stops |
| `download_green_taxi` | Source | HTTP status, file size | Green Taxi unavailable for the run |
| `download_open_meteo` | Source | HTTP status, JSON shape | Weather unavailable |
| `download_taxi_zones` | Source | HTTP status, row count | Location data unavailable |
| `ingest_green_taxi` | Bronze | Row count vs. source file | `green_taxi_silver` and everything downstream is stale |
| `ingest_open_meteo` | Bronze | Row count (2,208/period) | `dim_weather` stale/incomplete |
| `ingest_taxi_zones` | Bronze | Row count (265) | `dim_location` stale/incomplete |
| `clean_green_taxi` | Silver | MERGE row counts | `fact_taxi_trip` incomplete |
| `clean_taxi_zones` | Silver | MERGE row counts | `dim_location` incomplete |
| `clean_weather` | Silver | MERGE row counts | `dim_weather` incomplete |
| `dim_datetime` | Gold | Row count (2,209 = 2,208 + Unknown row) | Fact table INNER JOINs against this drop trips if incomplete |
| `dim_location` | Gold | Row count (265) | Fact table INNER JOINs against this drop trips if incomplete |
| `dim_weather` | Gold | Row count | Fact table LEFT JOIN — trips still load, `weather_key IS NULL` if incomplete |
| `fact_taxi_trip` | Gold | Row count vs. join result, key uniqueness | Every analytics query is affected |
| `taxi_demand`, `weather_demand_trip_behavior`, `strongest_mobility_patterns` | Analytics | Query completes without error | Dashboard output stale or wrong |

No task in this list runs a DQ check or depends on one.

## 3. DQ severity

| Status | Meaning |
|---|---|
| PASS | Check met expectations |
| WARN | A known, accepted condition |
| FAIL | Data is unsafe for downstream use |

Worked examples:

* `taxi_zones_silver`: 1 unexpected `borough`, 2 unexpected
  `service_zone` → WARN, not FAIL. These are `'Unknown'`/`'N/A'` —
  intentional values NYC's data uses for out-of-city or missing
  location info, not errors. See
  `docs/data_quality_checks/02_clean_checks/checks_taxi_zones_silver.md`.
* `dim_location`: same result — it's just the Gold copy of the same
  zone data.
* `fact_taxi_trip`'s weather check: trips can exist without matching
  weather data by design. This check only reports the count — it never
  flags it as a problem.

General pattern used across the existing checks: 1% tolerance for
NULL/UNIQUE/STANDARDIZATION/VALIDITY/LINEAGE checks, 2% tolerance for
VOLUME checks, before escalating from WARN to FAIL.

## 4. DQ results storage

DQ scripts under `src/sql/04_data_quality/` are standalone `SELECT`s.
There is no automated storage of results — each check has to be run
manually and its result recorded by hand into
`docs/data_quality_checks/`. The `nyc_quality` schema exists (created in
setup) but no table in it is currently written to.

## 5. Retry policy

Confirmed from `resources/nyc_mobility_job.yml` (committed in
source control, reproducible from a fresh `bundle deploy`):

- `max_retries: 2`, `min_retry_interval_millis: 30000` (30s) on exactly
  six tasks: `download_green_taxi`, `download_open_meteo`,
  `download_taxi_zones`, `ingest_green_taxi`, `ingest_open_meteo`,
  `ingest_taxi_zones`.
- Each of those six also has `notification_settings: alert_on_last_attempt: true`
  — the failure alert fires only after the final retry is exhausted.
- No retry config exists on any Silver, Gold, or Analytics task.
- Job-level `email_notifications: on_failure` sends to all 5 team
  members — a job-level setting, not per-task.

## 6. CI/CD flow

Verified from `.github/workflows/ci-cd.yml`:

- PR opened against `main`/`develop` → `validate` job runs: whitespace
  check (`git diff --check`) and `pytest tests/ -v`. `databricks bundle
  validate` does not run on a PR — only inside `deploy-dev`/`deploy-prod`,
  both gated `if: github.event_name == 'push'`.
- Merge is a manual approval step, not automatic.
- Push to `develop` → `databricks bundle validate --target dev` then
  `databricks bundle deploy --target dev`.
- Push to `main` → `databricks bundle validate --target prod` then
  `databricks bundle deploy --target prod`.
- Deployment mechanism: GitHub Actions → Databricks CLI → Databricks
  Asset Bundle. `DATABRICKS_HOST`/`DATABRICKS_TOKEN` are GitHub Secrets,
  injected only on push-triggered deploy jobs.
- Timeouts: `validate` = 10 min, `deploy-dev`/`deploy-prod` = 15 min
  each. `cancel-in-progress` applies only to `pull_request` events.
- Runtime for the Databricks Job itself (TBD): --

## 7. Schema drift

No current check detects a source schema change (new/removed columns,
type changes) — a known, unaddressed gap.
