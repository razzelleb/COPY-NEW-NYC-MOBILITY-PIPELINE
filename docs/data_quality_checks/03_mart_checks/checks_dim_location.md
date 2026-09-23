# Gold Dim Location Data Quality Checks

## Grain

**One row represents one unique NYC taxi location identified by `location_id`.**

- `location_key` is the warehouse surrogate primary key.
- `location_id` is the natural/business key from Silver.

## DQ Checks

| Check | Type | What is validated | Expected |
|---|---|---|---|
| Row count | VOLUME | Gold row count compared with unique Silver locations | Gold count = Silver unique `location_id` count |
| Missing `location_key` | NULL | Surrogate key completeness | 0 failures |
| Duplicate `location_key` | UNIQUE | Surrogate key uniqueness | 0 duplicates |
| Missing `location_id` | NULL | Business key completeness | 0 failures |
| Duplicate location business key | UNIQUE | One Gold row per `location_id` | 0 duplicates |
| Missing borough | NULL | Borough completeness | 0 failures |
| Missing zone | NULL | Zone completeness | 0 failures |
| Missing service_zone | NULL | Service zone completeness | 0 failures |
| Invalid `location_id` | RANGE | Location IDs must be positive | `location_id > 0` |
| Invalid borough value | ACCEPTED_VALUE | Borough values conform to expected NYC TLC values | Valid values are `BRONX`, `BROOKLYN`, `MANHATTAN`, `QUEENS`, `STATEN ISLAND`, `EWR` |
| Location has conflicting attributes | BUSINESS_RULE | A `location_id` should map consistently to borough, zone, and service zone | 0 conflicts |
| Silver locations missing from Gold | REFERENTIAL_INTEGRITY | Every unique Silver location exists in Gold | 0 missing |
| Gold locations missing from Silver | REFERENTIAL_INTEGRITY | Every Gold location exists in Silver | 0 missing |

## Summary

| Metric | Result |
|---|---:|
| Records checked | 265 |
| Total DQ checks | 13 |
| PASS | 12 |
| WARN | 1 |
| FAIL | 0 |

## Detailed Results

| # | Check Name | Check Type | Records Checked | Failures | Expected | Actual | Failure % | Status |
|---:|---|---|---:|---:|---|---:|---:|---|
| 1 | Invalid borough value | `ACCEPTED_VALUE` | 265 | 2 | BRONX, BROOKLYN, MANHATTAN, QUEENS, STATEN ISLAND, EWR | 2 | 0.75% | **WARN** |
| 2 | Location has conflicting attributes | `BUSINESS_RULE` | 0 | 0 | 0 | 0 | N/A | **PASS** |
| 3 | Missing borough | `NULL` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 4 | Missing location_id | `NULL` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 5 | Missing location_key | `NULL` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 6 | Missing service_zone | `NULL` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 7 | Missing zone | `NULL` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 8 | Invalid location_id | `RANGE` | 265 | 0 | > 0 | 0 | 0.00% | **PASS** |
| 9 | Gold locations missing from Silver | `REFERENTIAL_INTEGRITY` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 10 | Silver locations missing from Gold | `REFERENTIAL_INTEGRITY` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 11 | Duplicate location business key | `UNIQUE` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 12 | Duplicate location_key | `UNIQUE` | 265 | 0 | 0 | 0 | 0.00% | **PASS** |
| 13 | Row count | `VOLUME` | 265 | 0 | 265 | 265 | 0.00% | **PASS** |


## Result Interpretation

The `dim_location` DQ validation returned:

**12 PASS, 1 WARN, and 0 FAIL**

The only warning is the `ACCEPTED_VALUE` check for `borough`.

Two records contain borough values outside the currently defined accepted-value list:

- `Unknown`
- `N/A`
  
``` text
Retain valid text entries such as 'Unknown' and 'N/A' across borough, zone, and service_zone to preserve official NYC TLC spatial definitions, explicitly distinguishing Unknown (uncaptured or missing GPS/meter data) from N/A (non-applicable attributes, such as out-of-city trips or non-regulated service zones).
```

## Conclusion

The Gold location dimension passed all defined DQ checks with one warning and no failures. The table contains the expected 265 unique locations, with valid and unique `location_id` business keys and `location_key` surrogate keys. No missing location attributes, conflicting location attributes, or inconsistencies between the Silver and Gold location IDs were detected. The only warning was related to two `borough` values, `Unknown` and `N/A`. These values were intentionally retained to preserve the official NYC TLC spatial definitions, distinguishing `Unknown` values from uncaptured or missing location information and `N/A` values from non-applicable attributes such as out-of-city trips or non-regulated service zones.

The dimension is ready to be referenced by the Gold fact table for location-based mobility analysis and pickup/drop-off area analysis.


