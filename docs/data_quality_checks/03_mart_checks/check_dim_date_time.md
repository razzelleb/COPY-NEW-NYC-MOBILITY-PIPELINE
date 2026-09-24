# Gold Date/Time Data Quality Checks

The `nyc.nyc_gold.dim_datetime` table contains synthesized hourly datetime records, modeled as a Gold dimension for use with the taxi trip fact table.

These checks validate that the Gold datetime dimension remains complete, unique, standardized, traceable, and consistent with the expected source period.

| *Check* | *Purpose* | *What is Checked* | *Expected Result* |
| ----- | ----- | ----- | ----- |
| Completeness | Ensures required calendar attributes are populated | `datetime_key`, `full_datetime`, `date`, `day_name`, and `month_name` are not NULL | 0 incomplete rows |
| Uniqueness | Ensures one record exists per datetime observation | Duplicate `datetime_key` values | 0 duplicate keys |
| Lineage | Ensures records can be traced to their Gold processing time | `gold_ingestion_date` and `gold_ingestion_timestamp` are populated | 0 missing lineage values |
| Standardization | Ensures flags and text are analytically valid | Text fields have no padding; weekend and rush hour logic is correct | 0 invalid rows |
| Date Range | Ensures the expected time boundaries are enforced | Dates are strictly within March 1, 2026 to May 31, 2026 (excluding sentinel row) | 0 out-of-range rows |
| Volume | Ensures the exact sequence of hours was generated | Total number of Gold datetime records | 2,209 rows |

## Validation Result

All 13 Gold Date/Time DQ checks passed with *0 failed rows*:

- *Completeness — PASS:* No required calendar fields are NULL.
- *Lineage — PASS:* Gold ingestion metadata columns are fully populated.
- *Standardization — PASS:* Text values are standardized and boolean flag logic (weekend/rush hour) evaluates correctly.
- *Uniqueness — PASS:* No duplicate `datetime_key` primary keys were found.
- *Date Range — PASS:* All generated dates accurately reflect the March–May 2026 constraints.
- *Volume — PASS:* The table contains the expected 2,209 records (2,208 hourly rows + 1 Unknown row).

## Expected Data Coverage

The Gold datetime dimension contains hourly records covering:

*March 1, 2026 00:00 to May 31, 2026 23:00*, plus one sentinel "Unknown" mapping row.

This represents *2,209 expected records*.

## Gold Transformation

The Gold layer transforms a continuous generated time series into a dimensional structure. 

The `datetime_key` is generated as a Gold surrogate key, while categorical calendar attributes and analytical flags (`is_weekend`, `is_rush_hour`, `time_period`) are derived from the root `full_datetime`. An explicit `datetime_key = 0` record is preserved to gracefully map missing or out-of-bounds dates from downstream fact tables.

The Gold load uses an idempotent `MERGE INTO` execution, equipped with a `WHEN NOT MATCHED BY SOURCE THEN DELETE` clause to seamlessly clean up orphaned rows if the date range generation is modified.

## Conclusion

The Gold datetime dimension passed all 13 defined DQ checks with no detected issues. The table contains the expected volume of contiguous hourly observations, accurately derived calendar flags, complete attributes, and unique keys. 

The dimension is ready to be referenced by the Gold fact tables for time-series mobility analysis.