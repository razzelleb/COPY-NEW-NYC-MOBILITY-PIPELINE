# Weather Bronze Data Quality Checks

The `nyc.nyc_bronze.weather_bronze` table stores raw Open-Meteo hourly weather data for March–May 2026.

The Bronze DQ checks verify that the ingested data is complete, valid, unique, traceable, and covers the expected source period.

| Check           | Purpose                                                           | Expected Result                         |
| --------------- | ----------------------------------------------------------------- | --------------------------------------- |
| Completeness    | Checks required weather fields for NULL values                    | 0 incomplete rows                       |
| Uniqueness      | Checks for duplicate weather timestamps                           | 0 duplicate timestamps                  |
| Lineage         | Checks source and ingestion metadata                              | 0 missing lineage values                |
| Validity        | Checks for negative precipitation, snowfall, rain, or wind values | 0 invalid rows                          |
| Volume          | Confirms the expected number of hourly records                    | 2,208 rows                              |
| Timestamp Range | Confirms the expected source coverage                             | Mar 1, 2026 00:00 to May 31, 2026 23:00 |

### Validation Result

All six Bronze DQ checks passed with **0 failed rows**:

* Completeness — PASS
* Lineage — PASS
* Timestamp Range — PASS
* Uniqueness — PASS
* Validity — PASS
* Volume — PASS

This confirms that the current March–May 2026 Open-Meteo Bronze dataset was ingested successfully without detected completeness, duplication, lineage, validity, volume, or timestamp-range issues.

Transformation-specific checks are handled in the Silver layer.
