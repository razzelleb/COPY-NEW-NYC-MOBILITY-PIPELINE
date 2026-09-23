# Open-Meteo — dlt Ingestion

## Overview

This document covers the replacement of the Open-Meteo weather ingestion path
with **dlt** (data load tool), in place of the previous manual
`download_open_meteo.py` + `ingest_open_meteo.py` scripts. This is not a
side-by-side evaluation track — dlt is now the actual source feeding the
Gold-layer weather dimension, which `fact_taxi_trip` joins against.

## Where dlt fits

```text
Open-Meteo API → dlt (dlt_ingest_weather.py) → weather_bronze_dlt
    → clean_weather_dlt → dim_weather_dlt → fact_taxi_trip
```

The original `download_open_meteo.py`, `ingest_open_meteo.py`,
`clean_weather.sql`, and `dim_weather.sql` files and their job tasks have
been removed from `resources/nyc_mobility_job.yml` — they are no longer part
of the pipeline. `fact_taxi_trip.sql`'s weather join now targets
`nyc.nyc_gold.dim_weather_dlt` directly, so `fact_taxi_trip` — and everything
downstream of it (`taxi_demand`, `weather_demand_trip_behavior`,
`strongest_mobility_patterns`) — depends on the dlt-based chain.

## Why dlt was used

The previous Open-Meteo ingestion loaded data with a full `.mode("overwrite")`
every run — the same "batch, not idempotent" problem identified for Green
Taxi ingestion. dlt was adopted because it handles merge-based idempotent
loading, schema typing, and lineage tracking without hand-written MERGE SQL.

## Implementation

- `src/sql/01_bronze_ingest/dlt_ingest_weather.py` — dlt pipeline, merges on
  `primary_key="timestamp"`, `write_disposition="merge"`. Uses local
  `.dlt/secrets.toml` when run locally, and Databricks Secrets
  (`dbutils.secrets.get("dlt-weather", ...)`) when run inside a job.
- `src/sql/02_silver_clean/clean_weather_dlt.sql` — same cleaning logic as
  the retired `clean_weather.sql`, sourced from `weather_bronze_dlt`.
- `src/sql/03_gold_model/dim_weather_dlt.sql` — same dimension logic as the
  retired `dim_weather.sql`, sourced from `clean_weather_dlt`.
- `src/sql/03_gold_model/fact_taxi_trip.sql` — weather `LEFT JOIN` now
  targets `nyc.nyc_gold.dim_weather_dlt` instead of the retired
  `dim_weather`.
- `resources/nyc_mobility_job.yml` — `dlt_ingest_weather` → `clean_weather_dlt`
  → `dim_weather_dlt` are real pipeline tasks feeding `fact_taxi_trip`
  directly (added `dlt_env` environment for the `dlt[databricks]` +
  `dlt[parquet]` dependencies). The old `download_open_meteo`,
  `ingest_open_meteo`, `clean_weather`, and `dim_weather` tasks were removed.

## Test Results

| Check | Result |
|---|---|
| Bronze initial load row count | 2,208 |
| Bronze rerun row count | 2,208 — unchanged |
| Bronze duplicate `timestamp` count after rerun | 0 |
| Bronze schema (`DESCRIBE`) | All 7 source fields + 3 lineage fields, plus `_dlt_load_id`, `_dlt_id` |
| Row count vs. the retired `weather_bronze` table | 2,208 (matched before retirement) |
| Silver (`clean_weather_dlt`) row count | 2,208 |
| Gold (`dim_weather_dlt`) row count | 2,208 |
| Manual reruns of Bronze/Silver/Gold | Stable, no duplicates |

All manual, local, and SQL-Editor-run checks pass. Idempotency confirmed
across multiple reruns at every layer.

## Comparison vs. the retired manual ingestion

| Aspect | Previous (retired) | dlt (current) |
|---|---|---|
| Idempotency | None — full overwrite every run | Native via `write_disposition="merge"` |
| Schema | Manually cast | Typed via `columns={...}`, verified via `DESCRIBE` |
| Lineage | Custom columns only | Custom columns + built-in `_dlt_load_id`/`_dlt_id` |
| Compute | Required a Spark session | Runs via SQL Warehouse, no Spark needed |
| Dependencies | None | `dlt[databricks]`, `dlt[parquet]`, separate SQL Warehouse token |

## Evaluation

**Benefits** — Idempotency came for free via `merge` write disposition,
eliminating hand-written MERGE SQL. Schema and lineage tracking are stronger
than the retired approach with less custom code.

**Limitations** — Introduces a second ingestion pattern (SQL Warehouse
connection vs. Spark) alongside the rest of the pipeline. Requires managing a
separate credential (SQL Warehouse token via Databricks Secrets) and, for
local development, real setup friction (Python/venv, missing `pyarrow`
dependency hit during testing).

**Complexity vs. payoff** — Open-Meteo is a small, fixed-shape API; most of
dlt's heavier machinery (pagination, incremental cursors, large-scale schema
evolution) barely gets exercised here. What was proven is narrower but real:
merge-based idempotency with no custom code, now load-bearing for the actual
fact table.

## Deployment Status

`fact_taxi_trip` now depends on `dim_weather_dlt`, so the dlt chain is
required, not optional, for the pipeline to fully run. The full chain has
been deployed and run against a personal `dev` job target. All original
(non-weather) tasks succeed. `dlt_ingest_weather` currently fails when run on
**serverless** job compute, with a network error (`Connection refused`)
reaching the Unity Catalog volume staging endpoint used internally by dlt's
Databricks destination during file upload. The same script runs successfully
outside of serverless compute (confirmed working locally). This appears to be
a serverless network egress restriction specific to this workspace, not an
issue with the ingestion logic — it has been flagged to the workspace admin
for review.

**This branch should not be merged into `main` / deployed to the shared
production job until the serverless networking issue is resolved.** Because
`fact_taxi_trip` now depends on the dlt chain, merging before that fix would
break `fact_taxi_trip` (and everything downstream of it) in the shared job,
not just leave a side table stale.

## Conclusion

The dlt-based ingestion is fully built, tested, and proven idempotent at
every layer (Bronze, Silver, Gold) through manual and local execution, and is
correctly wired as the pipeline's actual weather source, feeding
`fact_taxi_trip` directly. The only remaining blocker is a workspace-level
serverless networking restriction outside this work's scope to resolve —
a known, documented limitation, not a defect in the implementation.
