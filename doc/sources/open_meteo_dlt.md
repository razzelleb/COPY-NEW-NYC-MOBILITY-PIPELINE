# Open-Meteo — dlt Ingestion

## Overview

This document covers the replacement of the Open-Meteo weather ingestion path
with **dlt** (data load tool), in place of the previous manual
`download_open_meteo.py` + `ingest_open_meteo.py` scripts. dlt is the real
source feeding the Gold-layer weather dimension used by production analytics.
The original `fact_taxi_trip` and its underlying weather chain
(`download_open_meteo`/`ingest_open_meteo`/`clean_weather`/`dim_weather`) are
**untouched** — a parallel `_dlt`-suffixed chain (`fact_taxi_trip_dlt` and
weather tables) is what's actually live and feeding analytics.

## Where dlt fits

```text
Open-Meteo API → dlt (dlt_ingest_weather.py, runs via GitHub Actions)
    → weather_bronze_dlt → clean_weather_dlt → dim_weather_dlt
    → fact_taxi_trip_dlt → taxi_demand / weather_demand_trip_behavior
                            / strongest_mobility_patterns
```

Critically, **ingestion (Bronze) runs outside Databricks entirely**, as a
GitHub Actions step — not a Databricks Job task. See "Why ingestion runs in
GitHub Actions, not Databricks" below for why.

## Why dlt was used

The previous Open-Meteo ingestion loaded data with a full `.mode("overwrite")`
every run — the same "batch, not idempotent" problem identified for Green
Taxi ingestion. dlt was adopted because it handles merge-based idempotent
loading, schema typing, and lineage tracking without hand-written MERGE SQL.

## Why ingestion runs in GitHub Actions, not Databricks

Extensive testing showed dlt's Databricks destination cannot run on this
workspace's **serverless** compute, in any form:

| Where it was tried | Result |
|---|---|
| Local machine (laptop) | ✅ Always worked |
| Databricks Job task (`spark_python_task`) | ❌ `Connection refused` |
| Live Databricks notebook, serverless compute | ❌ `Connection refused`, even at dlt 1.30.0 with "Direct Load" |
| Two separate, confirmed-different Databricks workspaces | ❌ Same error in both |

The failure always happened at the same specific step: dlt stages a local
parquet file, then uploads it to a Unity Catalog Volume via an HTTPS `PUT` to
a presigned URL (`*.storage.cloud.databricks.com`) before loading it into the
table. That upload call gets refused specifically on serverless compute —
Databricks Free Edition restricts network egress for serverless compute in a
way that blocks this. It is not a code defect: the SQL Warehouse connection
itself always worked fine; only this one file-upload call was blocked.

Ruled out along the way: a misconfigured SQL Warehouse ID, a PAT missing the
`sql` scope, and an outdated dlt version — none of these were the actual
cause; the error persisted after each was fixed. A quick attempt at dlt's
`insert_values` loader format (to bypass file staging entirely) was also
tried, but it's not supported by the Databricks destination.

**The fix**: run `dlt_ingest_weather.py` as a step in
`.github/workflows/ci-cd.yml` (job: `ingest_weather`) instead of inside
Databricks. GitHub Actions runners have normal, unrestricted network access —
architecturally the same as a laptop — so the exact same script that always
worked locally also works from there. Credentials are supplied via GitHub
Secrets (`DATABRICKS_HOST`, `DATABRICKS_HTTP_PATH`, `DLT_ACCESS_TOKEN`),
mirroring the same env-var pattern the script already uses for Databricks Job
execution.

Verified as a genuine fix, not a false positive: confirmed via dlt's own
`_dlt_loads` audit table that separate runs produce distinct, fresh load IDs
with current timestamps (an early test appeared to succeed but had actually
reused a stale load ID — caught and confirmed against a truly new run).

## Implementation

- `src/sql/01_bronze_ingest/dlt_ingest_weather.py` — dlt pipeline, merges on
  `primary_key="timestamp"`, `write_disposition="merge"`. Credentials via
  local `.dlt/secrets.toml` for local runs, or env vars
  (`DESTINATION__DATABRICKS__CREDENTIALS__*`) supplied by GitHub Actions
  secrets in CI. Date range is **dynamic**, not hardcoded — `TARGET_MONTH =
  get_previous_month()` mirrors the same logic Green Taxi uses, so the
  ingested window automatically shifts to "last month" on every run without
  a code change. (Added per PR review feedback; originally hardcoded to
  March–May 2026 for initial testing.)
- `src/sql/02_silver_clean/clean_weather_dlt.sql` — sourced from
  `weather_bronze_dlt`; runs as a Databricks Job task, trusting that
  GitHub Actions has already populated Bronze before the job runs.
- `src/sql/03_gold_model/dim_weather_dlt.sql` — sourced from
  `clean_weather_dlt`.
- `src/sql/03_gold_model/fact_taxi_trip_dlt.sql` — parallel copy of the
  original `fact_taxi_trip.sql`, joined to `dim_weather_dlt` instead of
  `dim_weather`. The original `fact_taxi_trip.sql`/table is untouched and no
  longer runs as part of the job.
- `src/sql/05_analytics/taxi_demand.sql`,
  `weather_demand_trip_behavior.sql`, `strongest_mobility_patterns.sql` —
  repointed to read from `fact_taxi_trip_dlt` (and `dim_weather_dlt` where
  weather is joined directly).
- `resources/nyc_mobility_job.yml` — `clean_weather_dlt` → `dim_weather_dlt`
  → `fact_taxi_trip_dlt` → the three analytics tasks. No `dlt_ingest_weather`
  task exists in this file; Bronze ingestion is external.
- `.github/workflows/ci-cd.yml` — `ingest_weather` job, currently triggered
  manually (`workflow_dispatch`). Installs `dlt[databricks]`/`dlt[parquet]`
  and runs the ingestion script.

## Test Results

Original testing used a fixed March–May 2026 range (before the date range
became dynamic — see Implementation above):

| Check | Result |
|---|---|
| Bronze initial load row count | 2,208 |
| Bronze rerun row count | 2,208 — unchanged |
| Bronze duplicate `timestamp` count after rerun | 0 |
| Bronze schema (`DESCRIBE`) | All 7 source fields + 3 lineage fields, plus `_dlt_load_id`, `_dlt_id` |
| Silver (`clean_weather_dlt`) row count | 2,208 |
| Gold (`dim_weather_dlt`) row count | 2,208 |
| GitHub Actions run — fresh load ID confirmed | ✅ via `_dlt_loads` table, distinct `load_id`/`inserted_at` per run |
| GitHub Actions run — end-to-end success | ✅ (56s total run time on a clean pass) |

**After switching to the dynamic `TARGET_MONTH` range**: rerunning against
the live table (which already held the 2,208 March–May rows) correctly
**added** August 2026 (`TARGET_MONTH` resolved to "2026-08" at time of
testing) as new rows rather than replacing anything — count went from 2,208
to **2,952**, exactly matching 2,208 + (31 days × 24 hours) = 2,208 + 744.
Confirms the merge logic and the new dynamic date range both work correctly
together.

Idempotency confirmed across many reruns, locally, in Databricks SQL Editor,
and via GitHub Actions — reruns of the *same* month stay stable with no
duplicates; a new month correctly appends rather than overwriting.

## Comparison vs. the retired manual ingestion

| Aspect | Previous (retired) | dlt (current) |
|---|---|---|
| Idempotency | None — full overwrite every run | Native via `write_disposition="merge"` |
| Schema | Manually cast | Typed via `columns={...}`, verified via `DESCRIBE` |
| Lineage | Custom columns only | Custom columns + built-in `_dlt_load_id`/`_dlt_id` |
| Compute | Required a Spark session, ran inside Databricks | Runs via SQL Warehouse from GitHub Actions, outside Databricks |
| Dependencies | None | `dlt[databricks]`, `dlt[parquet]`, GitHub Actions secrets |

## Evaluation

**Benefits** — Idempotency came for free via `merge` write disposition,
eliminating hand-written MERGE SQL. Schema and lineage tracking are stronger
than the retired approach with less custom code.

**Limitations** — Introduces a second ingestion pattern (SQL Warehouse
connection vs. Spark), a separate execution environment (GitHub Actions
rather than Databricks), and real local/CI setup friction along the way
(Python/PATH conflicts, PAT scope mismatches, a Databricks CLI bundle-context
ambiguity that surfaced in both local and CI testing).

**Complexity vs. payoff** — Open-Meteo is a small, fixed-shape API; most of
dlt's heavier machinery (pagination, incremental cursors, large-scale schema
evolution) barely gets exercised here. What was proven is narrower but real:
merge-based idempotency with no custom code — and a genuine, hard platform
constraint (serverless network restrictions) that had to be engineered
around, not just theorized about.

## Deployment Status

**Working.** The `ingest_weather` GitHub Actions job successfully populates
`weather_bronze_dlt`, verified via fresh, distinct entries in dlt's own
`_dlt_loads` audit table on each run. The Databricks Job
(`clean_weather_dlt` → `dim_weather_dlt` → `fact_taxi_trip_dlt` → analytics)
runs separately and successfully in Databricks, reading whatever Bronze data
GitHub Actions most recently populated.

**Known gap, not yet automated**: GitHub Actions is currently triggered
**manually**. For full production automation, two follow-ups remain, not yet
implemented:
1. Add a `schedule:` (cron) trigger to `ci-cd.yml` so ingestion runs on its
   own, with no manual click.
2. Chain the two systems (GitHub Actions auto-triggering the Databricks job
   via `databricks jobs run-now`) so one trigger runs everything end to end.
   A first attempt worked after fixing a CLI ambiguity (`--target dev`), but
   was reverted after an unrelated job timeout briefly looked like it might
   be caused by the change (confirmed it wasn't — the same timeout happened
   with chaining removed too, most likely the shared SQL Warehouse under
   load). Reverted anyway to keep things simple on shared CI/CD
   infrastructure until there's time to reintroduce and verify it properly.

## Conclusion

The dlt-based ingestion is fully built, tested, and proven idempotent at
every layer (Bronze, Silver, Gold), and is now genuinely running in
production via GitHub Actions — not blocked, not theoretical. The Databricks
Free Edition serverless networking restriction that blocked in-platform
execution was identified, exhaustively diagnosed, and engineered around by
moving ingestion to a different, unrestricted execution environment. The
original `fact_taxi_trip` and weather pipeline remain completely untouched
throughout.
