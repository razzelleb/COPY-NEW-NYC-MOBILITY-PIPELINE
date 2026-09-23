-- BUSINESS QUESTION: How does weather affect taxi demand and trip behavior?
-- Standalone SELECT queries only - no CREATE TABLE / CREATE VIEW, no new schema.
-- Each query below is self-contained (own CTE) so it can be pasted individually into a dashboard widget.
-- SOURCE: fact_taxi_trip_dlt (1 row/trip) LEFT JOIN dim_weather_dlt (1 row/hour) via weather_key.


-- =====================================================================
-- QUERY 1: DEMAND AND TRIP BEHAVIOR BY WEATHER CONDITION
-- =====================================================================

WITH trip_weather AS (
    SELECT
        f.trip_key, f.trip_distance, f.trip_duration_minutes, f.fare_amount,
        f.tip_amount, f.total_amount, f.passenger_count, f.lpep_pickup_datetime,
        COALESCE(w.weather_condition, 'No Weather Data') AS weather_condition,
        w.weather_key, w.temperature_2m, w.precipitation, w.snowfall, w.wind_speed_10m
    FROM nyc.nyc_gold.fact_taxi_trip_dlt AS f
    LEFT JOIN nyc.nyc_gold.dim_weather_dlt AS w ON f.weather_key = w.weather_key
    WHERE f.trip_distance BETWEEN 0 AND 100
      AND f.trip_duration_minutes BETWEEN 0 AND 180
      AND f.fare_amount BETWEEN 0 AND 250
      AND f.passenger_count BETWEEN 1 AND 8
)
SELECT
    weather_condition,
    COUNT(*) AS trip_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total_trips,
    CASE WHEN COUNT(*) < 200 THEN 'LOW SAMPLE - interpret with caution' ELSE 'OK' END AS sample_size_flag,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_min,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance_mi,
    ROUND(AVG(fare_amount), 2) AS avg_fare_amount,
    ROUND(AVG(total_amount), 2) AS avg_total_amount,
    ROUND(AVG(tip_amount), 2) AS avg_tip_amount,
    ROUND(AVG(passenger_count), 2) AS avg_passenger_count,
    ROUND(AVG(CASE WHEN trip_distance > 0 THEN fare_amount / trip_distance END), 2) AS avg_fare_per_mile,
    ROUND(AVG(temperature_2m), 1) AS avg_temperature_c,
    ROUND(AVG(wind_speed_10m), 1) AS avg_wind_speed
FROM trip_weather
GROUP BY weather_condition
ORDER BY trip_count DESC;


-- =====================================================================
-- QUERY 2: DEMAND AND TRIP BEHAVIOR BY PRECIPITATION INTENSITY
-- =====================================================================

WITH trip_weather AS (
    SELECT
        f.trip_distance, f.trip_duration_minutes, f.fare_amount, f.total_amount, f.passenger_count,
        CASE
            WHEN w.weather_key IS NULL THEN 'No Weather Data'
            WHEN COALESCE(w.precipitation, 0) = 0 THEN 'No Precipitation'
            WHEN w.precipitation <= 2.5 THEN 'Light (0-2.5mm)'
            WHEN w.precipitation <= 7.5 THEN 'Moderate (2.5-7.5mm)'
            ELSE 'Heavy (7.5mm+)'
        END AS precipitation_bucket
    FROM nyc.nyc_gold.fact_taxi_trip_dlt AS f
    LEFT JOIN nyc.nyc_gold.dim_weather_dlt AS w ON f.weather_key = w.weather_key
    WHERE f.trip_distance BETWEEN 0 AND 100
      AND f.trip_duration_minutes BETWEEN 0 AND 180
      AND f.fare_amount BETWEEN 0 AND 250
      AND f.passenger_count BETWEEN 1 AND 8
)
SELECT
    precipitation_bucket,
    COUNT(*) AS trip_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total_trips,
    CASE WHEN COUNT(*) < 200 THEN 'LOW SAMPLE - interpret with caution' ELSE 'OK' END AS sample_size_flag,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_min,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance_mi,
    ROUND(AVG(fare_amount), 2) AS avg_fare_amount,
    ROUND(AVG(total_amount), 2) AS avg_total_amount,
    ROUND(AVG(CASE WHEN trip_distance > 0 THEN fare_amount / trip_distance END), 2) AS avg_fare_per_mile
FROM trip_weather
GROUP BY precipitation_bucket
ORDER BY
    CASE precipitation_bucket
        WHEN 'No Weather Data' THEN 0
        WHEN 'No Precipitation' THEN 1
        WHEN 'Light (0-2.5mm)' THEN 2
        WHEN 'Moderate (2.5-7.5mm)' THEN 3
        WHEN 'Heavy (7.5mm+)' THEN 4
    END;


-- =====================================================================
-- QUERY 3: SNOW VS NO SNOW
-- =====================================================================

WITH trip_weather AS (
    SELECT
        f.trip_distance, f.trip_duration_minutes, f.fare_amount, f.total_amount, f.passenger_count,
        CASE
            WHEN w.weather_key IS NULL THEN 'No Weather Data'
            WHEN COALESCE(w.snowfall, 0) > 0 THEN 'Snow'
            ELSE 'No Snow'
        END AS snow_flag
    FROM nyc.nyc_gold.fact_taxi_trip_dlt AS f
    LEFT JOIN nyc.nyc_gold.dim_weather_dlt AS w ON f.weather_key = w.weather_key
    WHERE f.trip_distance BETWEEN 0 AND 100
      AND f.trip_duration_minutes BETWEEN 0 AND 180
      AND f.fare_amount BETWEEN 0 AND 250
      AND f.passenger_count BETWEEN 1 AND 8
)
SELECT
    snow_flag,
    COUNT(*) AS trip_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total_trips,
    CASE WHEN COUNT(*) < 200 THEN 'LOW SAMPLE - interpret with caution' ELSE 'OK' END AS sample_size_flag,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_min,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance_mi,
    ROUND(AVG(fare_amount), 2) AS avg_fare_amount,
    ROUND(AVG(total_amount), 2) AS avg_total_amount,
    ROUND(AVG(CASE WHEN trip_distance > 0 THEN fare_amount / trip_distance END), 2) AS avg_fare_per_mile
FROM trip_weather
WHERE snow_flag != 'No Weather Data'
GROUP BY snow_flag
ORDER BY snow_flag;


-- =====================================================================
-- QUERY 4: TAXI DEMAND PER WEATHER HOUR (normalized demand)
-- =====================================================================

WITH trip_date_bounds AS (
    SELECT MIN(lpep_pickup_datetime) AS min_pickup, MAX(lpep_pickup_datetime) AS max_pickup
    FROM nyc.nyc_gold.fact_taxi_trip_dlt
    WHERE lpep_pickup_datetime IS NOT NULL
),
trip_counts AS (
    SELECT
        COALESCE(w.weather_condition, 'No Weather Data') AS weather_condition,
        COUNT(*) AS trip_count
    FROM nyc.nyc_gold.fact_taxi_trip_dlt AS f
    LEFT JOIN nyc.nyc_gold.dim_weather_dlt AS w ON f.weather_key = w.weather_key
    WHERE f.trip_distance BETWEEN 0 AND 100
      AND f.trip_duration_minutes BETWEEN 0 AND 180
      AND f.fare_amount BETWEEN 0 AND 250
      AND f.passenger_count BETWEEN 1 AND 8
    GROUP BY COALESCE(w.weather_condition, 'No Weather Data')
),
weather_hours AS (
    -- Bounds truncated to the hour to match the fact table's date_trunc('hour', ...) join logic
    SELECT
        COALESCE(w.weather_condition, 'No Weather Data') AS weather_condition,
        COUNT(DISTINCT w.weather_datetime) AS weather_hours
    FROM nyc.nyc_gold.dim_weather_dlt AS w
    CROSS JOIN trip_date_bounds AS b
    WHERE w.weather_datetime >= date_trunc('hour', b.min_pickup)
      AND w.weather_datetime <= date_trunc('hour', b.max_pickup)
    GROUP BY COALESCE(w.weather_condition, 'No Weather Data')
)
SELECT
    t.weather_condition,
    t.trip_count,
    w.weather_hours,
    ROUND(t.trip_count * 1.0 / NULLIF(w.weather_hours, 0), 2) AS trips_per_weather_hour
FROM trip_counts AS t
LEFT JOIN weather_hours AS w ON t.weather_condition = w.weather_condition
ORDER BY trips_per_weather_hour DESC;


-- =====================================================================
-- QUERY 5: WEATHER COMPARISON BY MONTH (seasonality check)
-- =====================================================================

WITH trip_weather AS (
    SELECT
        f.trip_distance, f.trip_duration_minutes, f.fare_amount, f.passenger_count, f.lpep_pickup_datetime,
        COALESCE(w.weather_condition, 'No Weather Data') AS weather_condition
    FROM nyc.nyc_gold.fact_taxi_trip_dlt AS f
    LEFT JOIN nyc.nyc_gold.dim_weather_dlt AS w ON f.weather_key = w.weather_key
    WHERE f.trip_distance BETWEEN 0 AND 100
      AND f.trip_duration_minutes BETWEEN 0 AND 180
      AND f.fare_amount BETWEEN 0 AND 250
      AND f.passenger_count BETWEEN 1 AND 8
)
SELECT
    DATE_FORMAT(lpep_pickup_datetime, 'yyyy-MM') AS trip_month,
    weather_condition,
    COUNT(*) AS trip_count,
    CASE WHEN COUNT(*) < 200 THEN 'LOW SAMPLE - interpret with caution' ELSE 'OK' END AS sample_size_flag,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_min,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance_mi,
    ROUND(AVG(fare_amount), 2) AS avg_fare_amount,
    ROUND(AVG(CASE WHEN trip_distance > 0 THEN fare_amount / trip_distance END), 2) AS avg_fare_per_mile
FROM trip_weather
GROUP BY DATE_FORMAT(lpep_pickup_datetime, 'yyyy-MM'), weather_condition
ORDER BY trip_month, trip_count DESC;


-- HOW TO READ: Q1 = demand/behavior by condition. Q2 = does behavior scale with precipitation intensity?
-- Q3 = snow vs. non-snow. Q4 = trips_per_weather_hour is the normalized demand signal.
-- Q5 = checks whether weather differences hold within individual months.
-- NOTE: descriptive associations only, not causal proof.