# Silver Weather Data Quality Checks

The `nyc.nyc_silver.clean_weather` table contains cleaned and standardized hourly weather data from Open-Meteo for March–May 2026.

These checks validate that the data remains complete, unique, valid, traceable, and consistent after being processed from the Bronze layer.

| Check        | Purpose                                                               | What is Checked                                                                                    | Expected Result          |
| ------------ | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------ |
| Completeness | Ensures required weather data is available                            | `timestamp`, temperature, precipitation, rain, snowfall, wind speed, and weather code are not NULL | 0 incomplete rows        |
| Uniqueness   | Ensures one record exists per hourly observation                      | Duplicate `timestamp` values                                                                       | 0 duplicate timestamps   |
| Lineage      | Ensures records can be traced back to the source and processing steps | Source file, ingestion metadata, and Silver processing metadata are populated                      | 0 missing lineage values |
| Validity     | Ensures weather measurements contain valid values                     | Precipitation, rain, snowfall, and wind speed are not negative                                     | 0 invalid rows           |
| Volume       | Ensures the expected number of weather observations is present        | Total number of Silver records                                                                     | 2,208 rows               |

### Validation Result

All five Silver DQ checks passed with **0 failed rows**:

* **Completeness — PASS:** No required weather fields are NULL.
* **Lineage — PASS:** Source and processing metadata are populated.
* **Uniqueness — PASS:** No duplicate hourly timestamps were found.
* **Validity — PASS:** No negative weather measurements were detected.
* **Volume — PASS:** The table contains the expected 2,208 hourly records.

### Expected Data Coverage

The Silver table contains hourly weather observations covering:

**March 1, 2026 00:00 to May 31, 2026 23:00**

This represents **2,208 expected hourly records**.

### Conclusion

The Silver weather data passed all defined DQ checks with no detected issues. The data is ready for use in the Gold layer, where it can be connected to taxi trip data for weather-related analysis.
