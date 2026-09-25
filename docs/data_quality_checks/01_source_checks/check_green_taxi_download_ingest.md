# Green Taxi Download vs. Bronze Ingest Data Quality Checks Report (March–May 2026)

## 1. Overview
This document logs the data quality (DQ) validation results for the **NYC Green Taxi** dataset spanning **March through May 2026** (133,367 total records) [1, 2].

Validations are captured at two key stages of the Medallion pipeline:
1. **Raw Download Layer**: Inspects raw Parquet files landed in Unity Catalog Volume (`/Volumes/nyc/default/nyc-mobility-volume/green_taxi/`) [1].
2. **Bronze Ingest Layer**: Inspects records post-deduplication and idempotent `MERGE INTO` in `nyc.nyc_bronze.green_taxi_bronze` [2].

---

## 2. Comparison Matrix: Raw Download vs. Bronze Ingest Stage

The side-by-side comparison below maps the exact validation results from the **Download** (`final download may .png`) [1] and **Bronze Ingestion** (`final ingest may .png`) [2] stages:

| Check Name | Check Type | Download Stage Result [1] | Bronze Ingest Stage Result [2] | Status Variance & Resolution |
| :--- | :--- | :--- | :--- | :--- |
| **Total Row / Loaded Count** | `VOLUME` | **133,367** records / 0 affected (0.00%) — **PASS** | **133,367** records / 0 affected (0.00%) — **PASS** | **Aligned** (Exact volume match across layers) [1, 2] |
| **Duplicate composite key check (7-columns)** | `UNIQUE` | **133,367** checked / 0 affected (0.00%) — **PASS** | **133,367** checked / 0 affected (0.00%) — **PASS** | **Aligned** (Zero composite natural key duplicates) [1, 2] |
| **Exact duplicate rows** | `UNIQUE` | **133,367** checked / 0 affected (0.00%) — **PASS** | **133,367** checked / 0 affected (0.00%) — **PASS** | **Aligned** (Zero identical duplicate rows) [1, 2] |
| **Null count for mandatory key fields (7-columns)** | `NULL` | **133,367** checked / 0 affected (0.00%) — **PASS** | **133,367** checked / 0 affected (0.00%) — **PASS** | **Aligned** (100% complete on essential key attributes) [1, 2] |
| **Audit lineage population** | `LINEAGE` | *N/A (Raw File Level)* | **133,367** checked / 0 affected (0.00%) — **PASS** | **Bronze Addition** (100% lineage coverage added) [2] |
| **Non-positive trip distance** | `RANGE` | *N/A (Skipped in Download)* | **133,367** checked / 4,592 affected (**3.44%**) — **FAIL** | **Flagged in Bronze** (Exceeds 2% limit; cleaned in Silver) [2] |
| **Negative total amount** | `RANGE` | *N/A (Skipped in Download)* | **133,367** checked / 391 affected (**0.29%**) — **WARN** | **Flagged in Bronze** (Within warning threshold ≤ 2%) [2] |

---

## 3. Monthly Volume & Lineage Parity

Both stages verified identical monthly row counts across file source batches and taximeter pickup dates [1, 2]:

| Month / Partition | Source Batch Count (Download [1] / Ingest [2]) | Pickup Date Timestamp Count [1, 2] | Variance & Operational Notes |
| :--- | :--- | :--- | :--- |
| **2008-12** | - | 2 | Taximeter clock drift (retained in Bronze) [1, 2] |
| **2009-01** | - | 1 | Taximeter clock drift (retained in Bronze) [1, 2] |
| **2026-02** | - | 8 | Late-month pickup timestamp adjustment [1, 2] |
| **2026-03** | 44,208 | 44,200 | -8 trips crossed into Feb/Apr pickup dates [1, 2] |
| **2026-04** | 44,238 | 44,243 | +5 trips boundary adjustment [1, 2] |
| **2026-05** | 44,921 | 44,913 | -8 trips boundary adjustment [1, 2] |
| **Total** | **133,367** | **133,367** | **0 Row Loss Across Stages (PASS)** [1, 2] |

---

## 4. Summary & Pipeline Action Items

1. **Volume & Key Integrity (PASS)**: Raw download and Bronze Delta ingestion match at 133,367 rows with 0 duplicate key records and 0 exact duplicate rows [1, 2].
2. **Audit Lineage (PASS)**: Bronze table columns (`source_file`, `source_month`, `bronze_ingestion_timestamp`, `bronze_ingestion_date`) achieved 100% population [2].
3. **Data Quality Anomalies**:
   - **`Non-positive trip distance` (3.44%)** [2]: Exceeds the 2.00% failure threshold. As per Medallion architecture guidelines, raw records are preserved in Bronze for auditability and filtered out during Silver transformation.
   - **`Negative total amount` (0.29%)** [2]: Falls within the warning threshold (≤ 2.00%) representing standard meter credit/dispute adjustments.
