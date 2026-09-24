# NYC Green Taxi — April 2026 Documentation

## Stretch Goal

Retrieve the official NYC Taxi & Limousine Commission (TLC) Green Taxi Trip Record data for **April 2026**, inspect the Parquet file, and produce evidence that the data is ready to move into a **Databricks ingestion pipeline**.

## Project Structure

```
nyc-taxi-project/
├── .venv/
├── data/
│   └── raw/
│       └── green_tripdata_2026-04.parquet
├── output/
│   └── schema.csv
├── download_data.py
├── inspect_data.py
├── null_report.py
├── null_pattern.py
├── key_analysis.py
├── quality_check.py
├── date_anomaly.py
└── green_taxi_april_2026_data_quality.md
```

---

## 1. Data Ingestion — `download_data.py`

Pulls the raw Parquet file directly from TLC's CloudFront-hosted source and saves it to `data/raw/`.

```python
import requests
from pathlib import Path

URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2026-04.parquet"
OUTPUT_FILE = Path("data/raw/green_tripdata_2026-04.parquet")

print("Starting download...")
print("Please wait...")

OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
response = requests.get(URL, stream=True)
response.raise_for_status()

with open(OUTPUT_FILE, "wb") as file:
    for chunk in response.iter_content(chunk_size=1024 * 1024):
        if chunk:
            file.write(chunk)

print("Download complete!")
print(f"File saved to: {OUTPUT_FILE}")
```

**Note:** This is a direct file download, not web scraping — the URL points straight to a Parquet file, so no HTML parsing is required.

---

## 2. Inspection Result

```
NYC GREEN TAXI - APRIL 2026
==========================
Total rows: 44,238
Total columns: 21
```

| column_name | data_type |
|---|---|
| VendorID | int32 |
| lpep_pickup_datetime | timestamp[us] |
| lpep_dropoff_datetime | timestamp[us] |
| store_and_fwd_flag | large_string |
| RatecodeID | int64 |
| PULocationID | int32 |
| DOLocationID | int32 |
| passenger_count | int64 |
| trip_distance | double |
| fare_amount | double |
| extra | double |
| mta_tax | double |
| tip_amount | double |
| tolls_amount | double |
| ehail_fee | double |
| improvement_surcharge | double |
| total_amount | double |
| payment_type | int64 |
| trip_type | int64 |
| congestion_surcharge | double |
| cbd_congestion_fee | double |

### Dimensions (attributes to filter/group by)

| column_name | data_type | remarks |
|---|---|---|
| VendorID | int32 | categorical |
| lpep_pickup_datetime | timestamp[us] | time dimension |
| lpep_dropoff_datetime | timestamp[us] | time dimension |
| store_and_fwd_flag | large_string | flag/category |
| RatecodeID | int64 | categorical |
| PULocationID | int32 | location dimension (pickup zone) |
| DOLocationID | int32 | location dimension (dropoff zone) |
| payment_type | int64 | categorical |
| trip_type | int64 | categorical |

### Measures (numeric values to aggregate/sum/avg)

| column_name | data_type |
|---|---|
| passenger_count | int64 |
| trip_distance | double |
| fare_amount | double |
| extra | double |
| mta_tax | double |
| tip_amount | double |
| tolls_amount | double |
| ehail_fee | double |
| improvement_surcharge | double |
| total_amount | double |
| congestion_surcharge | double |
| cbd_congestion_fee | double |

> **Note:** e-hail (electronic hail) means using a smartphone app to request an on-demand yellow taxicab or green street-hail livery.

### Flags

- **`ehail_fee`** → expected to be almost entirely NULL in the null report — this is normal, not a data quality failure.
- **`RatecodeID`, `payment_type`, `trip_type`** → these are lookup codes, not true numbers. Flagged here so nobody accidentally runs `AVG()` or `SUM()` on them downstream.

---

## 3. Null Results

| column_name | null_count | null_percentage |
|---|---|---|
| ehail_fee | 44,238 | 100% |
| store_and_fwd_flag | 6,290 | 14.22% |
| congestion_surcharge | 6,290 | 14.22% |
| passenger_count | 6,290 | 14.22% |
| RatecodeID | 6,290 | 14.22% |
| payment_type | 6,290 | 14.22% |
| trip_type | 6,290 | 14.22% |
| Other columns | 0 | 0% |

### Null Patterns

```
000000 -> 37,948 rows
111111 -> 6,290 rows
```

Column order: `store_and_fwd_flag`, `congestion_surcharge`, `passenger_count`, `RatecodeID`, `payment_type`, `trip_type`

Because `111111` means every one of the six columns is NULL, this confirms the same 6,290 records have NULL values across all six fields simultaneously — pointing to a shared root cause (e.g. a batch of trips missing metering/rate data) rather than random, unrelated missingness.

---

## 4. Business Key Analysis

### Exact Duplicate Rows

```
Duplicate rows: 0
```

### Single-Column Uniqueness

| column_name | unique values | % unique | interpretation |
|---|---|---|---|
| VendorID | 3 | 0.01% | Only 3 taxi vendors exist — a dimension, not a key |
| lpep_pickup_datetime | 43,480 | 98.29% | Most trips have distinct timestamps |
| lpep_dropoff_datetime | 43,537 | 98.42% | Most trips have distinct timestamps |
| PULocationID | 237 | 0.54% | Only ~260 zones exist citywide — a dimension, not a key |
| DOLocationID | 247 | 0.56% | Only ~260 zones exist citywide — a dimension, not a key |

### Composite Business Key

Tested key: `VendorID`, `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `PULocationID`, `DOLocationID`, `trip_distance`

```
Unique combinations: 44,084
Total rows:           44,238
Duplicate-key rows:   308
```

- 308 rows share a key with at least one other row — the composite key is **not fully unique**.
- Adding another column (e.g. `fare_amount` or `payment_type`) possibly add distinction to this dataset.
- Near-duplicate trips (same vendor, same timestamps, same zones, same distance) are plausible in real taxi data — this is treated as a **known limitation**, not a data quality bug.

---

## 5. Quality Checks

**Rows loaded:** 44,238

| # | Check | Result |
|---|---|---|
| 1 | Earliest pickup | 2026-03-31 23:28:50 |
| 1 | Latest pickup | 2026-05-01 07:53:18 |
| 1 | Earliest dropoff | 2026-04-01 00:15:53 |
| 1 | Latest dropoff | 2026-05-02 07:07:21 |
| 2 | Dropoff before pickup | 0 |
| 3 | Negative trip distance | 0 |
| 3 | Zero trip distance | 1,604 |
| 4 | Negative fares | 153 |
| 4 | Zero fares | 633 |
| 5 | Negative total amounts | 155 |
| 5 | Zero total amounts | 62 |
| 6 | Negative passenger counts | 0 |
| 6 | Zero passenger counts | 543 |
| 7 | Unique pickup locations | 237 |
| 7 | Unique dropoff locations | 247 |

### Code Value Checks

| column_name | observed values |
|---|---|
| VendorID | 1, 2, 6 |
| RatecodeID | 1.0, 2.0, 3.0, 4.0, 5.0 |
| payment_type | 1.0, 2.0, 3.0, 4.0 |
| trip_type | 1.0, 2.0 |

All observed code values fall within TLC's documented valid ranges — no unexpected or out-of-spec codes found.

---

## Summary

- **Row count:** 44,238 rows loaded, no exact duplicates.
- **Nulls:** Concentrated in a known 6,290-row block (`111111` pattern) plus a 100%-NULL `ehail_fee` column — both explainable, not random corruption.
- **Keys:** No natural single-column key exists (as expected for trip-level data); the 6-column composite key is 99.3% unique, with 308 rows needing a tiebreaker column.
- **Value ranges:** Some zero/negative fare and distance values exist (likely cancelled trips, promos, or refunds) — flagged for downstream handling rather than treated as errors.
- **Codes:** All categorical codes (VendorID, RatecodeID, payment_type, trip_type) match TLC's documented valid values.
