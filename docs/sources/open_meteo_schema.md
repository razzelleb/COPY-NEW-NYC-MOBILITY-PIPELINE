# Open-Meteo Historical Weather API – Source Analysis

## 1. Source Overview

The Open-Meteo Historical Weather API provides historical weather data through a REST API. For this project, it is used to provide hourly weather conditions for New York City during the analysis period.

**Source:** Open-Meteo Historical Weather API
**Endpoint:** `https://archive-api.open-meteo.com/v1/archive`
**Location:** New York City
**Requested latitude:** `40.7128`
**Requested longitude:** `-74.0060`
**Period:** March 1, 2026 – May 31, 2026
**Timezone:** `America/New_York`
**Grain:** One row per hourly weather observation

The API returned a model/grid location of approximately latitude `40.738136` and longitude `-74.04254`, which is near the requested coordinates.

---

## 2. API Parameters

The following parameters were used to retrieve the weather data:

| Parameter  | Value              | Purpose                             |
| ---------- | ------------------ | ----------------------------------- |
| latitude   | `40.7128`          | NYC latitude                        |
| longitude  | `-74.0060`         | NYC longitude                       |
| start_date | `2026-03-01`       | Start of analysis period            |
| end_date   | `2026-05-31`       | End of analysis period              |
| hourly     | Weather fields     | Weather variables to retrieve       |
| timezone   | `America/New_York` | Return timestamps in NYC local time |

### Requested Weather Fields

* `temperature_2m`
* `precipitation`
* `rain`
* `snowfall`
* `wind_speed_10m`
* `weather_code`

---

## 3. Source Data Structure

The API response contains metadata and an `hourly` object.

The `hourly` object contains the timestamp and weather variables as arrays. Values at the same array position correspond to the same hourly observation.

| Field            | Data Type         | Unit       | Description                 | Category    |
| ---------------- | ----------------- | ---------- | --------------------------- | ----------- |
| `time`           | String / datetime | Local time | Hour of weather observation | Timestamp   |
| `temperature_2m` | Numeric           | °C         | Air temperature at 2 meters | Measure     |
| `precipitation`  | Numeric           | mm         | Total precipitation         | Measure     |
| `rain`           | Numeric           | mm         | Rain amount                 | Measure     |
| `snowfall`       | Numeric           | cm         | Snowfall amount             | Measure     |
| `wind_speed_10m` | Numeric           | km/h       | Wind speed at 10 meters     | Measure     |
| `weather_code`   | Integer           | WMO code   | Weather condition code      | Categorical |

---

## 4. Observation Count and Completeness

The requested period covers March through May 2026, consisting of 92 calendar days.

With hourly observations:

`92 days × 24 hours = 2,208 expected observations`

The API returned exactly **2,208 timestamps**.

| Check                   | Expected | Actual | Status |
| ----------------------- | -------: | -----: | ------ |
| Hourly observations     |    2,208 |  2,208 | PASS   |
| `time` values           |    2,208 |  2,208 | PASS   |
| `temperature_2m` values |    2,208 |  2,208 | PASS   |
| `precipitation` values  |    2,208 |  2,208 | PASS   |
| `rain` values           |    2,208 |  2,208 | PASS   |
| `snowfall` values       |    2,208 |  2,208 | PASS   |
| `wind_speed_10m` values |    2,208 |  2,208 | PASS   |
| `weather_code` values   |    2,208 |  2,208 | PASS   |

All requested hourly arrays contain the expected number of observations.

---

## 5. NULL / Missing Value Analysis

Each requested weather field was checked for NULL values.

| Field            | NULL Count | Status |
| ---------------- | ---------: | ------ |
| `time`           |          0 | PASS   |
| `temperature_2m` |          0 | PASS   |
| `precipitation`  |          0 | PASS   |
| `rain`           |          0 | PASS   |
| `snowfall`       |          0 | PASS   |
| `wind_speed_10m` |          0 | PASS   |
| `weather_code`   |          0 | PASS   |

No NULL values were found across the 2,208 hourly observations.

**Finding:** The selected Open-Meteo fields have complete values for the requested period.

---

## 6. Timestamp and Key Analysis

The first timestamp returned was:

`2026-03-01T00:00`

The last timestamp returned was:

`2026-05-31T23:00`

The API returned **2,208 unique timestamps** with **0 duplicate timestamps**.

| Check                |             Result | Status |
| -------------------- | -----------------: | ------ |
| First timestamp      | `2026-03-01T00:00` | PASS   |
| Last timestamp       | `2026-05-31T23:00` | PASS   |
| Total timestamps     |              2,208 | PASS   |
| Unique timestamps    |              2,208 | PASS   |
| Duplicate timestamps |                  0 | PASS   |

The `time` field can be used as the natural time identifier for hourly weather observations.

**Finding:** No duplicate timestamps were identified, and the timestamp range fully covers the requested analysis period.

---

## 7. Numeric Range Analysis

The minimum and maximum values of the weather variables were inspected for obvious invalid values.

| Field            |  Minimum |   Maximum | Status |
| ---------------- | -------: | --------: | ------ |
| `temperature_2m` |   -9.9°C |    35.8°C | PASS   |
| `precipitation`  |   0.0 mm |    4.5 mm | PASS   |
| `rain`           |   0.0 mm |    4.5 mm | PASS   |
| `snowfall`       |   0.0 cm |   0.98 cm | PASS   |
| `wind_speed_10m` | 0.2 km/h | 33.1 km/h | PASS   |
| `weather_code`   |        0 |        75 | PASS   |

Negative temperatures are valid weather observations and do not represent a data-quality issue.

Precipitation, rain, snowfall, and wind speed are all non-negative.

**Finding:** No obvious invalid numeric values were identified during source profiling.

---

## 8. Weather Code Analysis

The dataset contains 12 distinct weather codes:

`0, 1, 2, 3, 51, 53, 55, 61, 63, 71, 73, 75`

The `weather_code` field represents WMO weather condition codes and should therefore be treated as a categorical field rather than a continuous numerical measure.

**Finding:** All observed weather codes are numeric WMO codes, with no NULL values.

---

## 9. Source Data Quality Summary

| Data Quality Check                                |            Result | Status |
| ------------------------------------------------- | ----------------: | ------ |
| API response                                      |          HTTP 200 | PASS   |
| Expected observation count                        |             2,208 | PASS   |
| Actual observation count                          |             2,208 | PASS   |
| Missing timestamps                                |                 0 | PASS   |
| Missing weather values                            |                 0 | PASS   |
| Duplicate timestamps                              |                 0 | PASS   |
| Date range complete                               |               Yes | PASS   |
| Invalid negative precipitation/rain/snowfall/wind |                 0 | PASS   |
| Weather codes present                             | 12 distinct codes | PASS   |

### Overall Finding

The Open-Meteo response is structurally complete and suitable for ingestion. The requested period is fully covered, all selected hourly fields contain values, timestamps are unique, and no obvious invalid numeric values were identified.

---

## 10. Role in the Data Pipeline

The Open-Meteo data will be ingested from the REST API and processed through the project's data pipeline.

### Planned Pipeline

```text
Open-Meteo REST API
        ↓
      Bronze
  Raw API response
        ↓
      Silver
Standardized hourly weather
        ↓
       Gold
   Analytical data
```

The hourly grain allows weather observations to be associated with other datasets using the corresponding date and hour.

---

## 11. Initial Engineering Considerations

* The source is accessed through a REST API and returns JSON data.
* The requested period is explicitly defined as March 1 to May 31, 2026.
* The hourly timestamp will be retained as the primary time reference for each observation.
* Weather measurements will retain their source units during ingestion.
* `weather_code` will be treated as a categorical field.
* The raw API response should be preserved in the Bronze layer before transformation.
* The ingestion process should be repeatable to support incremental and idempotent processing.
