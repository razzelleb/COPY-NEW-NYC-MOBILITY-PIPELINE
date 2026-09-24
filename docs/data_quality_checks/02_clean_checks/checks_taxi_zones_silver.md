# Silver Taxi Zone Data Quality Checks

The `nyc.nyc_silver.taxi_zones_silver` table contains cleaned and standardized NYC Taxi & Limousine Commission (TLC) zone location data, including boroughs, zones, and service zones. 

These checks validate that the data remains complete, unique, valid, traceable, and consistent after being processed from the Bronze layer.

| **Check** | **Purpose** | **What is Checked** | **Expected Result** |
| ----- | ----- | ----- | ----- |
| Completeness | Ensures required location data is available | `location_id`, `borough`, `zone`, and `service_zone` are not NULL | 0 incomplete rows |
| Uniqueness | Ensures one record exists per zone | Duplicate `location_id` primary keys | 0 duplicate IDs |
| Lineage | Ensures records can be traced back to the processing steps | Silver processing metadata (`silver_ingestion_date`, `silver_ingestion_timestamp`) are populated | 0 missing lineage values |
| Standardization | Ensures text strings are clean for downstream joins | `borough` and `zone` contain no unhandled leading or trailing whitespaces | 0 unstandardized rows |
| Validity | Ensures categorical location data matches accepted NYC TLC values | `borough` and `service_zone` match expected lists | 0 invalid rows |
| Volume | Ensures the expected number of taxi zones is present | Total number of Silver records matches Bronze records | 265 rows |

## Validation Result

The Silver DQ framework executed 11 checks. 9 checks passed, and 2 checks triggered a warning status:

- **Completeness — PASS:** No required location fields are NULL.
- **Lineage — PASS:** Processing metadata columns are populated.
- **Uniqueness — PASS:** No duplicate `location_id` records were found.
- **Standardization — PASS:** No unstandardized text strings were detected.
- **Volume — PASS:** The table matches the expected Bronze row count of 265 rows.
- **Validity — WARN:** Found 1 record with an unmapped `borough` (0.38%) and 2 records with an unmapped `service_zone` (0.75%). These correspond to 'N/A' values. They have not been changed due to the following requirement:
  - **Special Values:** Retain valid text entries such as 'Unknown' and 'N/A' across `borough`, `zone`, and `service_zone` to preserve official NYC TLC spatial definitions, explicitly distinguishing Unknown (uncaptured or missing GPS/meter data) from N/A (non-applicable attributes, such as out-of-city trips or non-regulated service zones).

## Expected Data Coverage

The Silver table contains location metadata mapping for all officially recognized NYC TLC taxi zones.

This represents **265 expected records**.

## Conclusion

The Silver taxi zone data passed all critical structural, volume, and completeness checks. The two validity warnings are intentional, as 'N/A' values are explicitly retained to maintain official spatial definitions for out-of-city and non-regulated zones. The data is ready for use in the Gold layer as a dimension table (`dim_location`) for geospatial taxi trip analysis.