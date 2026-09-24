# Gold Fact Taxi Trip Data Quality Checks

The `nyc.nyc_gold.fact_taxi_trip` table contains one row per Green Taxi trip, modeled as the Gold fact table at the center of the star schema, referencing `dim_datetime`, `dim_location`, and `dim_weather`.

These checks validate that the Gold fact table remains complete, unique, referentially consistent with all three dimensions, within valid value ranges, and traceable to its Silver source.

| *Check* | *Purpose* | *What is Checked* | *Expected Result* |
| ----- | ----- | ----- | ----- |
| Volume | Ensures the fact table reflects the ETL's own join intent | Actual row count vs. a re-derivation of the same Bronze→Silver→Gold join logic | Actual = expected (a lower count than raw Silver is normal — trips outside `dim_datetime`/`dim_location` range are intentionally excluded) |
| Completeness (surrogate) | Ensures the primary key is populated | `trip_key` is not NULL | 0 incomplete rows |
| Completeness (surrogate FKs) | Ensures all four role-playing dimension keys are populated | `pickup_datetime_key`, `dropoff_datetime_key`, `pickup_location_key`, `dropoff_location_key` are not NULL | 0 incomplete rows |
| Completeness (natural FKs) | Ensures the natural join columns are populated | `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `PULocationID`, `DOLocationID` are not NULL | 0 incomplete rows |
| Uniqueness (surrogate) | Ensures one record exists per `trip_key` | Duplicate `trip_key` values | 0 duplicate keys |
| Uniqueness (natural) | Ensures one Gold row exists per trip | Duplicate composite natural key (the same 7 columns Silver deduplicates on) | 0 duplicate keys |
| Referential Integrity (location) | Ensures every pickup and dropoff zone resolves in Gold | `pickup_location_key` and `dropoff_location_key` exist in `dim_location` | 0 orphaned rows |
| Referential Integrity (datetime) | Ensures every pickup and dropoff hour resolves in Gold | `pickup_datetime_key` and `dropoff_datetime_key` exist in `dim_datetime` | 0 orphaned rows |
| Referential Integrity (weather) | Confirms the optional weather join behaves as designed | Trips with a non-NULL `weather_key` that doesn't resolve in `dim_weather` | Informational only — `LEFT JOIN` to weather is by design, so this never fails the table |
| Range (distance) | Ensures trip distance is analytically valid | `trip_distance` is strictly positive, matching Silver's tightened rule | `trip_distance > 0` |
| Range (duration) | Ensures trip times are logically ordered | Dropoff is not before pickup | `trip_duration_minutes >= 0` |
| Range (fare) | Ensures financial values are valid | `fare_amount` and `total_amount` are not negative, matching Silver's tightened rules | `>= 0` |
| Range (passengers) | Ensures occupancy values are valid | `passenger_count` is strictly positive, matching Silver's tightened rule | `passenger_count > 0` |
| Standardization (codes) | Ensures categorical codes conform to TLC-defined or Silver sentinel values | `payment_type`, `trip_type`, and `ratecode_id` fall within accepted values | 0 invalid rows |
| Lineage | Ensures records can be traced to their Gold processing time | `gold_processed_date` and `gold_processed_timestamp` are populated | 0 missing lineage values |

## Validation Result

*Run `check_fact_taxi_trip.sql` against the current table and record the outcome here, in the same style as the other Gold dimension checks:*

- *Volume — [PASS/FAIL]:* [row count vs. expected]
- *Completeness — [PASS/FAIL]:* [summary]
- *Uniqueness — [PASS/FAIL]:* [summary]
- *Referential Integrity — [PASS/FAIL]:* [summary]
- *Range — [PASS/FAIL]:* [summary]
- *Standardization — [PASS/FAIL]:* [summary]
- *Lineage — [PASS/FAIL]:* [summary]

## Expected Data Coverage

The Gold fact table contains one row per trip that successfully passed `green_taxi_silver`'s cleaning rules (positive distance, positive passenger count, non-negative fare and total amount, valid time order) and joined successfully against `dim_datetime` and `dim_location`.

Following the tightening of `green_taxi_silver`'s filters, the Silver source row count dropped from 133,348 to *108,478*, and the fact table is expected to reflect this same reduction once reloaded.

## Gold Transformation

The Gold layer joins deduplicated `green_taxi_silver` trip records against all three Gold dimensions via `INNER JOIN` (location, datetime) to enforce referential integrity, and `LEFT JOIN` (weather) since weather coverage is optional. `dim_datetime` and `dim_location` are each referenced twice — once for pickup, once for dropoff — supplying surrogate keys for reporting, while the fact table retains Silver's original full-precision timestamps and natural location IDs for `MERGE` matching.

The Gold load uses an idempotent `MERGE INTO`, matching on the same composite natural key `green_taxi_silver` deduplicates on rather than on surrogate keys, since many trips share the same hour and zone and surrogate keys alone are not unique at this grain.

**Notable fixes:** an early version stored `dim_datetime`'s hour-truncated value instead of Silver's real timestamp, silently duplicating trips that shared an hour and zone. A later reload of `green_taxi_silver`'s filters left stale pre-filter rows in Gold until the fact table was fully reloaded, since `MERGE INTO` never deletes unmatched target rows on its own. Both were corrected, and the checks above were extended to catch the same failure modes automatically.

## Conclusion

The Gold fact table carries a full surrogate-key path to all three dimensions while preserving the natural-key matching needed for correct deduplication at this grain.

*Pending the final DQ run, this table is intended as the authoritative source for taxi demand, fare, weather-impact, and zone-level mobility analysis referenced by the dashboard.*
