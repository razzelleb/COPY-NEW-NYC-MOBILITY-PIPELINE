## NYC Green Taxi - May 2026 Insights

**Total Rows:** 44,921

**Total Columns:** 21


## Data Types
 |  # | Column                  | Data type       | What it represents                          | Category                  |
| -: | ----------------------- | --------------- | ------------------------------------------- | ------------------------- |
|  1 | `VendorID`              | `int32`         | Taxi/LPEP technology provider               | Dimension / Key candidate |
|  2 | `lpep_pickup_datetime`  | `timestamp[us]` | Trip pickup date/time                       | Dimension                 |
|  3 | `lpep_dropoff_datetime` | `timestamp[us]` | Trip dropoff date/time                      | Dimension                 |
|  4 | `store_and_fwd_flag`    | `large_string`  | Whether the record was stored and forwarded | Dimension                 |
|  5 | `RatecodeID`            | `int64`         | Rate code used for the trip                 | Dimension                 |
|  6 | `PULocationID`          | `int32`         | Pickup Taxi Zone ID                         | Dimension / Key candidate |
|  7 | `DOLocationID`          | `int32`         | Dropoff Taxi Zone ID                        | Dimension / Key candidate |
|  8 | `passenger_count`       | `int64`         | Number of passengers                        | Measure                   |
|  9 | `trip_distance`         | `double`        | Trip distance in miles                      | Measure                   |
| 10 | `fare_amount`           | `double`        | Meter fare                                  | Measure                   |
| 11 | `extra`                 | `double`        | Additional charges/extras                   | Measure                   |
| 12 | `mta_tax`               | `double`        | MTA tax                                     | Measure                   |
| 13 | `tip_amount`            | `double`        | Reported tip amount                         | Measure                   |
| 14 | `tolls_amount`          | `double`        | Toll charges                                | Measure                   |
| 15 | `ehail_fee`             | `double`        | E-hail fee field                            | Measure                   |
| 16 | `improvement_surcharge` | `double`        | Improvement surcharge                       | Measure                   |
| 17 | `total_amount`          | `double`        | Total amount charged                        | Measure                   |
| 18 | `payment_type`          | `int64`         | Payment method code                         | Dimension                 |
| 19 | `trip_type`             | `int64`         | Type of trip                                | Dimension                 |
| 20 | `congestion_surcharge`  | `double`        | Congestion surcharge                        | Measure                   |
| 21 | `cbd_congestion_fee`    | `double`        | CBD congestion fee                          | Measure                   |

## NULL Analysis
| Column(s)              | NULL rows |      NULL % | Interpretation          |
| ---------------------- | --------: | ----------: | ----------------------- |
| `ehail_fee`            |    44,921 | **100.00%** | Entire column is NULL   |
| `store_and_fwd_flag`   |     5,772 |  **12.85%** | Significant missingness |
| `congestion_surcharge` |     5,772 |  **12.85%** | Significant missingness |
| `passenger_count`      |     5,772 |  **12.85%** | Significant missingness |
| `RatecodeID`           |     5,772 |  **12.85%** | Significant missingness |
| `payment_type`         |     5,772 |  **12.85%** | Significant missingness |
| `trip_type`            |     5,772 |  **12.85%** | Significant missingness |
| All other columns      |         0 |   **0.00%** | No NULLs detected       |

**Insights**
- `ehail_fee` contains 100% NULL values in the May 2026 Green Taxi dataset. The field should be investigated before ingestion to determine whether it is intentionally unused/not populated or represents missing data. It should not automatically be converted to zero.
- 5,772 numbered rows pattern this strongly suggests these missing values may be associated with the same subset of records, rather than six unrelated missing-data problems.
- NULL pattern: 5,772 rows (12.85%) contain NULL values simultaneously in `store_and_fwd_flag`, `congestion_surcharge`, `passenger_count`, `RatecodeID`, `payment_type`, and `trip_type`. The remaining 39,149 rows have non-NULL values for all six fields. This indicates that the missing values are concentrated in the same subset of records rather than occurring independently across these columns.

## Key Analysis

**Exact duplicate rows: 0**
- No two rows are completely identical.
     
**No single-column primary key:**
- VendorID has only 3 unique values.
- Pickup/dropoff timestamps are highly unique, but not completely unique.
- Location IDs are clearly descriptive fields, not identifiers.
      
**Composite candidate: not unique.**
- 44,803 unique combinations out of 44,921 rows.
- 236 rows participate in duplicate combinations.

**Primary/business key: ** No explicit unique trip identifier is present in the dataset. No individual column qualifies as a primary key. A composite business-key candidate using `VendorID`, `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `PULocationID`, `DOLocationID`, and `trip_distance` was tested but was not unique, with 236 records involved in duplicate combinations. However, there were 0 exact duplicate rows, indicating that the duplicate composite-key combinations differ in at least one other column. Therefore, no formal primary key should be assumed without additional source-system documentation

## Data Quality
The May 2026 Green Taxi dataset contains 44,921 records and 21 columns.

**The main data-quality observations are:**

- No exact duplicate rows were found.
- No records have dropoff times before pickup times.
- No negative trip distances were found.
- 1,560 records have zero trip distance.
- 120 records have negative fares and 571 have zero fares.
- 123 records have negative total amounts and 123 have zero total amounts.
- 600 records have zero passenger counts.
- ehail_fee is 100% NULL.
- Six other fields contain NULLs on the same 5,772 records (12.85%).
- A pickup timestamp from December 31, 2008 is anomalous for a May 2026 dataset.
- No single-column or tested composite business key is unique.

### To check in Silver Layer

**Before production ingestion:**
- Investigate the anomalous 2008 timestamp.
- Investigate the 100% NULL ehail_fee field.
- Investigate the shared NULL pattern across the six affected columns.
- Review zero-distance, zero-passenger, zero-fare, negative-fare, and negative-total records.
- Do not automatically replace NULL or negative values without understanding their business meaning.
- Do not assume a primary key exists in the source dataset.
- Preserve the raw Parquet file so the original source data remains available for auditing.
