# Open-Meteo — dlt Ingestion

## Overview

This document covers an alternative Bronze ingestion path for the Open-Meteo
weather source, built with **dlt** (data load tool) instead of the existing
manual `download_open_meteo.py` + `ingest_open_meteo.py` scripts, built as a
non-destructive parallel evaluation track alongside the original pipeline.

## Where dlt fits

```text
Open-Meteo API → dlt (dlt_ingest_weather.py) → weather_bronze_dlt → clean_weather_dlt → dim_weather_dlt
```

This intentionally mirrors the original `download_open_meteo.py`/`ingest_open_meteo.py`
→ `clean_weather.sql` → `dim_weather.sql` chain, as a separate `_dlt`-suffixed
path. Nothing about the original pipeline was touched.

## Why dlt was used

The current Open-Meteo ingestion loads data with a full `.mode("overwrite")`
every run — the same "batch, not idempotent" problem identified for Green
Taxi ingestion. dlt was evaluated as an off-the-shelf alternative that handles
merge-based idempotent loading, schema typing, and lineage tracking without
hand-written MERGE SQL.

## Implementation

- `src/sql/01_bronze_ingest/dlt_ingest_weather.py` — dlt pipeline, merges on
  `primary_key="timestamp"`, `write_disposition="merge"`. Uses local
  `.dlt/secrets.toml` when run locally, and Databricks Secrets
  (`dbutils.secrets.get("dlt-weather", ...)`) when run inside a job.
- `src/sql/02_silver_clean/clean_weather_dlt.sql` — same cleaning logic as
  `clean_weather.sql`, sourced from `weather_bronze_dlt`.
- `src/sql/03_gold_model/dim_weather_dlt.sql` — same dimension logic as
  `dim_weather.sql`, sourced from `clean_weather_dlt`.
- `resources/nyc_mobility_job.yml` — added `dlt_ingest_weather` →
  `clean_weather_dlt` → `dim_weather_dlt` as new, additive tasks with a
  separate `dlt_env` environment, with zero changes to existing tasks.

## Test Results

| Check | Result |
|---|---|
| Bronze initial load row count | 2,208 |
| Bronze rerun row count | 2,208 — unchanged |
| Bronze duplicate `timestamp` count after rerun | 0 |
| Bronze schema (`DESCRIBE`) | All 7 source fields + 3 lineage fields, plus `_dlt_load_id`, `_dlt_id` |
| Row count vs. original `weather_bronze` table | 2,208 (matches) |
| Silver (`clean_weather_dlt`) row count | 2,208 |
| Gold (`dim_weather_dlt`) row count | 2,208 |
| Manual reruns of Silver/Gold | Stable, no duplicates |

All manual, local, and SQL-Editor-run checks pass. Idempotency confirmed
across multiple reruns at every layer.

## Comparison vs. current ingestion

| Aspect | Current | dlt |
|---|---|---|
| Idempotency | None — full overwrite every run | Native via `write_disposition="merge"` |
| Schema | Manually cast | Typed via `columns={...}`, verified via `DESCRIBE` |
| Lineage | Custom columns only | Custom columns + built-in `_dlt_load_id`/`_dlt_id` |
| Compute | Requires Spark session | Runs via SQL Warehouse, no Spark needed |
| Dependencies | None | `dlt[databricks]`, `dlt[parquet]`, separate SQL Warehouse token |

## Evaluation

**Benefits** — Idempotency came for free via `merge` write disposition,
eliminating hand-written MERGE SQL. Schema and lineage tracking are stronger
than the current approach with less custom code.

**Limitations** — Introduces a second ingestion pattern (SQL Warehouse
connection vs. Spark) alongside the existing pipeline. Requires managing a
separate credential (SQL Warehouse token via Databricks Secrets) and, for
local development, real setup friction (Python/venv, missing `pyarrow`
dependency hit during testing).

**Complexity vs. payoff** — Open-Meteo is a small, fixed-shape API; most of
dlt's heavier machinery (pagination, incremental cursors, large-scale schema
evolution) barely gets exercised here. What was proven is narrower but real:
merge-based idempotency with no custom code.

## Deployment Status

The full chain was deployed to the `dev` target (`databricks bundle deploy`)
and the job was triggered end-to-end. All original pipeline tasks succeeded.
The new `dlt_ingest_weather` task currently fails specifically when run on
**serverless** job compute, with a network error (`Connection refused`)
reaching the Unity Catalog volume staging endpoint used internally by dlt's
Databricks destination during file upload. The same script runs successfully
outside of serverless compute (local machine, confirmed working). This
appears to be a serverless network egress restriction specific to this
workspace, not an issue with the ingestion logic itself — it has been flagged
to the workspace admin for review. `clean_weather_dlt` and `dim_weather_dlt`
correctly did not run as a result (correct dependency behavior, not a
separate bug).

## Conclusion

The dlt-based ingestion is fully built, tested, and proven idempotent at
every layer (Bronze, Silver, Gold) through manual and local execution.
Automated execution via the production job is implemented and deployed, but
currently blocked by a workspace-level serverless networking restriction
outside this evaluation's scope to resolve — a known, documented limitation
rather than an unresolved defect in the implementation.
