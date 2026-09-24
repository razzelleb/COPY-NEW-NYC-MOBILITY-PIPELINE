# Silver Green Taxi Data Quality Checks

The `nyc.nyc_silver.green_taxi_silver` table contains cleaned and deduplicated Green Taxi trip data from the Bronze layer for March–May 2026.

These checks validate that the data remains complete, unique, standardized, traceable, and consistent after being processed from the Bronze layer.

| Check | Purpose | What is Checked | Expected Result |
|---|---|---|---|
| Completeness | Ensures required trip information is available | `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `PULocationID`, and `DOLocationID` are not NULL | 0 incomplete rows |
| Uniqueness | Ensures each trip is represented only once | Duplicate composite trip keys using `VendorID`, pickup/dropoff timestamps, pickup/dropoff locations, `trip_distance`, and `total_amount` | 0 duplicate trip keys |
| Lineage | Ensures records can be traced through the pipeline | Bronze source fields, Bronze ingestion metadata, and Silver processing metadata are populated | 0 missing lineage values |
| Standardization | Ensures categorical values follow the defined format | `store_and_fwd_flag` contains only `Y`, `N`, or `Unknown` | 0 invalid rows |
| Cleaned Fields | Ensures NULL handling was applied correctly | `RatecodeID`, `passenger_count`, `payment_type`, `trip_type`, and `congestion_surcharge` are not NULL | 0 incomplete rows |
| Volume | Ensures the expected number of records is present | Total number of Silver records after Bronze filtering and deduplication | Matches expected Bronze-derived count |

## Validation Result

All six Silver DQ checks passed with **0 failed rows**:

- **Completeness — PASS:** No required trip fields are NULL.
- **Uniqueness — PASS:** No duplicate composite trip keys were found.
- **Lineage — PASS:** Bronze source and ingestion metadata, along with Silver processing metadata, are populated.
- **Standardization — PASS:** All `store_and_fwd_flag` values follow the defined `Y`, `N`, or `Unknown` format.
- **Cleaned Fields — PASS:** Fields handled through NULL replacement contain no remaining NULL values.
- **Volume — PASS:** The Silver table contains the expected number of records after filtering and deduplication.

## Expected Data Coverage

The Silver table contains Green Taxi trip records covering: **March–May 2026**

The expected Silver row count is based on the Bronze data after:
1. Removing records with missing required trip fields.
2. Deduplicating records using the seven-column composite trip key.

The composite trip_key is:

```text
VendorID
lpep_pickup_datetime
lpep_dropoff_datetime
PULocationID
DOLocationID
trip_distance
total_amount