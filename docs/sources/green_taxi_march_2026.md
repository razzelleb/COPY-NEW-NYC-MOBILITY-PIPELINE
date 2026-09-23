## NYC Green Taxi - March 2026 Insights

**Total Rows:** 44,208  

**Total Columns:** 21  

## Data Types

| # | Column | Data type | What it represents | Category |
| :--- | :--- | :--- | :--- | :--- |
| 1 | VendorID | int32 | Taxi/LPEP technology provider | Dimension / Key candidate |
| 2 | lpep_pickup_datetime | timestamp[us] | Trip pickup date/time | Dimension |
| 3 | lpep_dropoff_datetime | timestamp[us] | Trip dropoff date/time | Dimension |
| 4 | store_and_fwd_flag | large_string | Whether the record was stored and forwarded | Dimension |
| 5 | RatecodeID | int64 | Rate code used for the trip | Dimension |
| 6 | PULocationID | int32 | Pickup Taxi Zone ID | Dimension / Key candidate |
| 7 | DOLocationID | int32 | Dropoff Taxi Zone ID | Dimension / Key candidate |
| 8 | passenger_count | int64 | Number of passengers | Measure |
| 9 | trip_distance | double | Trip distance in miles | Measure |
| 10 | fare_amount | double | Meter fare | Measure |
| 11 | extra | double | Additional charges/extras | Measure |
| 12 | mta_tax | double | MTA tax | Measure |
| 13 | tip_amount | double | Reported tip amount | Measure |
| 14 | tolls_amount | double | Toll charges | Measure |
| 15 | ehail_fee | double | E-hail fee field | Measure |
| 16 | improvement_surcharge | double | Improvement surcharge | Measure |
| 17 | total_amount | double | Total amount charged | Measure |
| 18 | payment_type | int64 | Payment method code | Dimension |
| 19 | trip_type | int64 | Type of trip | Dimension |
| 20 | congestion_surcharge | double | Congestion surcharge | Measure |
| 21 | cbd_congestion_fee | double | CBD congestion fee | Measure |

---

## NULL Analysis

| Column(s) | NULL rows | NULL % | Interpretation |
| :--- | :--- | :--- | :--- |
| ehail_fee | 44,208 | **100.00%** | Entire column is NULL |
| store_and_fwd_flag | 6,692 | **15.14%** | Significant missingness |
| congestion_surcharge | 6,692 | **15.14%** | Significant missingness |
| passenger_count | 6,692 | **15.14%** | Significant missingness |
| RatecodeID | 6,692 | **15.14%** | Significant missingness |
| payment_type | 6,692 | **15.14%** | Significant missingness |
| trip_type | 6,692 | **15.14%** | Significant missingness |
| All other columns | 0 | **0.00%** | No NULLs detected |

**Insights**
* 'ehail_fee' contains 100% NULL values in the March 2026 Green Taxi dataset. The field should be investigated before ingestion to determine whether it is intentionally unused/not populated or represents missing data. It should not automatically be converted to zero.
* There are 6,692 rows (15.14%) containing NULL values simultaneously in `store_and_fwd_flag`, `congestion_surcharge`, `passenger_count`, `RatecodeID`, `payment_type`, and `trip_type` (`111111` pattern).
* The remaining 37,516 rows (`000000` pattern) have non-NULL values for all six fields. This strongly indicates that missing values are concentrated in the same subset of dispatch records rather than occurring independently across columns.

---

## Key Analysis

**Exact duplicate rows: 0**
* No two rows are completely identical.

**No single-column primary key:**
* **VendorID** has only 3 unique values.
* **Pickup and dropoff timestamps** are near-unique (>98% distinct), but because multiple taxis often pick up or drop off passengers during the same second, timestamps alone cannot uniquely identify a single trip.
* **PULocationID** (232 unique) and **DOLocationID** (247 unique) are descriptive location zones, not identifiers.

**Composite candidate: not unique.**
* **44,096 unique combinations** out of 44,208 total rows.
* **224 rows** participate in duplicate composite key combinations.

**Primary/business key:** No explicit unique trip identifier is present in the dataset. A composite business-key candidate using `VendorID`, `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `PULocationID`, `DOLocationID`, and `trip_distance` was tested but was not unique, with 224 records involved in duplicate combinations. However, there were 0 exact duplicate rows, indicating that duplicate composite-key combinations differ in at least one other column. Therefore, no formal primary key should be assumed without additional source-system documentation.

---

## Data Quality

The March 2026 Green Taxi dataset contains 44,208 records and 21 columns.

**The main data-quality observations are:**
* No exact duplicate rows were found.
* 1 record has a dropoff timestamp before pickup time (`2009-01-01 10:21:01` dropoff vs. `2009-01-01 01:35:31` pickup).
* No negative trip distances were found.
* 1,428 records have zero trip distance.
* 111 records have negative fares and 687 have zero fares.
* 113 records have negative total amounts and 43 have zero total amounts.
* 584 records have zero passenger counts.
* ehail_fee is 100% NULL.
* Six other fields contain NULLs on the same 6,692 records (15.14%).
* A pickup timestamp from January 1, 2009 (`2009-01-01 01:35:31`) is anomalous for a March 2026 dataset.
* No single-column or tested composite business key is unique.

---

## To check in Silver Layer

**Before production ingestion:**
* Investigate the anomalous 2009 timestamp. Filter records by valid March dates (`2026-03-01` to `2026-03-31`).
* Investigate the 100% NULL `ehail_fee` field. 
* Handle dispatch NULL missingness (15.14%). Map missing values in categorical fields to explicit `'Unknown / Dispatch'` codes if needed.
* Investigate negative fares and totals. Review the 111 negative fare and 113 negative total records.
* Flag canceled transactions. Mark refund and reversal records so total revenue and trip counts remain accurate.
* Define month-boundary partitioning rules. Attribute trips to March based on `lpep_pickup_datetime` to correctly process spillover dropoffs into April.
* Do not assume a primary key exists in the source dataset.
* Preserve the raw Parquet file. Store the original file in the Databricks Volume as an immutable Bronze layer for auditing.
