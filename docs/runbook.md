# NYC Mobility Pipeline — Production Runbook

This document describes the pipeline as currently deployed. Work in
progress on improvements is tracked separately and is not reflected
here until merged.

## 1. Pipeline health check

### Status checklist (fill in per run)

| Area | What to check | Expected result | Status |
|---|---|---|---|
| Job | Overall run | SUCCESS |  |
| Green Taxi | Bronze load | Expected rows (~44k/month) |  |
| Open-Meteo | Bronze load | SUCCESS |  |
| Taxi Zones | Bronze load | 265 zones |  |
| Silver | Load succeeds | No errors |  |
| Gold | `dim_location` | 265 rows |  |
| Gold | `dim_datetime` | 2,209 rows |  |
| Gold | `dim_weather` | 2,208 rows |  |
| Gold | `fact_taxi_trip` | expected join volume — not yet confirmed, `checks_fact_taxi_trip.md` not recorded |  |
| Lineage | Sources → Gold | Traceable, no orphaned rows |  |

### Deeper checks

1. Databricks Job run status for `NYC Mobility Pipeline` — did every task complete?
2. Identify the failed task, if any, using the matrix in `monitoring.md` SECTION 2.
3. DQ checks currently have to be run manually and results recorded by
   hand — there is no automated DQ result to check.
4. Row counts on Gold tables against known values: `dim_datetime` = 2,209,
   `dim_location` = 265, `dim_weather` = 2,208.

## 2. If a task fails

1. Identify the failed task key (matches `monitoring.md` SECTION 2).
2. Open the task's output/log in the Databricks Job run.
3. Classify the failure: source/download, Bronze ingestion, Silver
   transformation, Gold modeling, or CI/deployment.
4. Fix, rerun the affected task, verify downstream tables.

## 3. Rerun safety

- `green_taxi_silver`, `taxi_zones_silver`, `clean_weather`, and all
  Gold tables use `MERGE INTO` with null-safe (`<=>`) matching — safe to
  rerun without creating duplicates.
- `ingest_green_taxi.py`, `ingest_open_meteo.py`, and `ingest_taxi_zones.py`
  currently write Bronze with `.mode("overwrite")` — a full overwrite
  each run, not incremental. *An incremental/idempotent version is in
  progress; see the deliverables list.*
- `dim_datetime`'s Gold load uses `MERGE INTO ... WHEN NOT MATCHED BY
  SOURCE THEN DELETE` — the only Gold table with delete-on-rerun
  behavior. The others only insert/update.

## 4. DQ failure

No task in `resources/nyc_mobility_job.yml` currently runs a DQ check or
depends on one. A DQ SQL script returning a FAIL result today has no
automated effect on the pipeline — checks have to be run manually, and
any action taken on the result is manual as well.

*An automated DQ gate — with blocking on FAIL and a result history — is
in progress; see the deliverables list.*

## 5. CI/CD flow

Verified directly against `.github/workflows/ci-cd.yml`:

```
PR opened against main/develop
   → validate job: git diff --check (whitespace), pytest tests/ -v
     (databricks bundle validate does NOT run on PR)
   → merge is a manual approval step, not automatic
   → push to develop:
        databricks bundle validate --target dev
        databricks bundle deploy --target dev
   → push to main:
        databricks bundle validate --target prod
        databricks bundle deploy --target prod
```

- Deployment mechanism: GitHub Actions → Databricks CLI → Databricks
  Asset Bundle. `DATABRICKS_HOST`/`DATABRICKS_TOKEN` are GitHub Secrets.
- Timeouts: `validate` = 10 min, `deploy-dev`/`deploy-prod` = 15 min
  each. `cancel-in-progress` applies only to `pull_request` events.
- **Retry policy** (confirmed directly from `resources/nyc_mobility_job.yml`,
  committed in source control): `max_retries: 2`,
  `min_retry_interval_millis: 30000` on exactly six tasks —
  `download_green_taxi`, `download_open_meteo`, `download_taxi_zones`,
  `ingest_green_taxi`, `ingest_open_meteo`, `ingest_taxi_zones`. Each
  also has `alert_on_last_attempt: true` — alert fires only after the
  final retry fails, not on every attempt. No retry on Silver/Gold/
  Analytics tasks. Job-level `email_notifications: on_failure` sends to
  all 5 team members' addresses (redact this file before using it in a
  public screenshot/slide — addresses are real).

## 6. Escalation

| Area | Owner |
|---|---|
| Green Taxi ingestion | Razz |
| Open-Meteo / dlt pipeline | Maeve |
| DQ check logic or DAG gating | Sara |
| CI/CD or Databricks bundle deploy | Yanna |
| Lineage / cross-cutting questions | Tricia |

## 7. Accessing and manually running the job

**Who to ask for access**: Sara owns the repository and the Databricks workspace.

**Once access is confirmed:**

1. Log into the shared workspace at the URL the team provides.
2. Left sidebar → Workflows (some Databricks versions label this "Jobs &
   Pipelines"). Find the job named `NYC Mobility Pipeline` — defined in
   `resources/nyc_mobility_job.yml`.
3. If it has run before, open the most recent run to see status. To
   trigger a fresh run, use "Run now" — check with the team first, since
   it shares compute with everyone else's work.
4. Each task shows pass/fail. Click into a failed task for its actual
   error log; cross-reference against the task matrix in `monitoring.md`
   SECTION 2 to know what that failure means downstream.
5. A task showing "success" doesn't guarantee the data is actually
   correct — verify with a SQL editor:

```sql
SELECT COUNT(*) FROM nyc.nyc_gold.dim_location;     -- expect 265
SELECT COUNT(*) FROM nyc.nyc_gold.dim_datetime;      -- expect 2,209
SELECT COUNT(*) FROM nyc.nyc_gold.dim_weather;       -- expect 2,208
SELECT COUNT(*) FROM nyc.nyc_gold.fact_taxi_trip;    -- expected count not yet confirmed
```

6. Document/Screenshot the run results and query outputs — this is real
   monitoring evidence, not documented expectation, and should replace
   the placeholder checkboxes in SECTION 1's status checklist once captured.
