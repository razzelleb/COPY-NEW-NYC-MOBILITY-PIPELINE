# Gold Weather Data Quality Checks

The `nyc.nyc_gold.dim_weather` table contains hourly weather data from Open-Meteo, modeled as a Gold dimension for use with the taxi trip fact table.

These checks validate that the Gold weather dimension remains complete, unique, valid, traceable through its weather key, and consistent with the expected source period.

| Check                    | Purpose                                                       | What is Checked                                                                  | Expected Result                         |
| ------------------------ | ------------------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------------------------- |
| Completeness             | Ensures required weather attributes are populated             | Weather datetime, measurements, weather code, and weather condition are not NULL | 0 incomplete rows                       |
| Uniqueness               | Ensures one record exists per weather observation             | Duplicate `weather_datetime` values                                              | 0 duplicate timestamps                  |
| Measurement Validity     | Ensures weather measurements contain valid values             | Precipitation, rain, snowfall, and wind speed are not negative                   | 0 invalid rows                          |
| Weather Code Mapping     | Ensures weather codes are translated to a condition           | Weather condition is not NULL or `Unknown`                                       | 0 unmapped conditions                   |
| Weather Key Completeness | Ensures every weather record has a surrogate key              | `weather_key` is not NULL                                                        | 0 missing keys                          |
| Weather Key Uniqueness   | Ensures each weather record has a unique Gold key             | Duplicate `weather_key` values                                                   | 0 duplicate keys                        |
| Volume                   | Ensures the expected number of hourly observations is present | Total number of Gold weather records                                             | 2,208 rows                              |
| Timestamp Range          | Ensures the expected source period is covered                 | Minimum and maximum weather timestamps                                           | Mar 1, 2026 00:00 to May 31, 2026 23:00 |

### Validation Result

All eight Gold Weather DQ checks passed with **0 failed rows**:

* **Completeness — PASS:** No required weather fields are NULL.
* **Measurement Validity — PASS:** No negative weather measurements were detected.
* **Timestamp Range — PASS:** The expected March–May 2026 period is covered.
* **Uniqueness — PASS:** No duplicate weather timestamps were found.
* **Volume — PASS:** The table contains the expected 2,208 hourly records.
* **Weather Code Mapping — PASS:** All weather codes have a mapped weather condition.
* **Weather Key Completeness — PASS:** No weather keys are NULL.
* **Weather Key Uniqueness — PASS:** No duplicate weather keys were found.

### Expected Data Coverage

The Gold weather dimension contains hourly weather observations covering:

**March 1, 2026 00:00 to May 31, 2026 23:00**

This represents **2,208 expected hourly records**.

### Gold Transformation

The Gold layer transforms the cleaned Silver weather data into a dimensional structure.

The `weather_key` is generated as a Gold surrogate key, while `weather_datetime` represents the natural hourly weather observation.

Weather codes are also translated into human-readable weather conditions based on the WMO weather code definitions.

The Gold load uses `MERGE` on `weather_datetime`, allowing the process to be rerun without creating duplicate weather records.

### Conclusion

The Gold weather dimension passed all defined DQ checks with no detected issues. The table contains the expected hourly observations, valid measurements, unique weather timestamps and keys, complete weather attributes, and mapped weather conditions.

The dimension is ready to be referenced by the Gold fact table for weather-related mobility analysis.