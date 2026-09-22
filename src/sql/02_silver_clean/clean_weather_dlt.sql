-- Evaluation track for dlt comparison; see doc/sources/open_meteo_dlt.md
-- Same logic as clean_weather.sql, sourced from the dlt-ingested Bronze table.

CREATE TABLE IF NOT EXISTS nyc.nyc_silver.clean_weather_dlt (
    timestamp TIMESTAMP,
    temperature_2m DOUBLE,
    precipitation DOUBLE,
    rain DOUBLE,
    snowfall DOUBLE,
    wind_speed_10m DOUBLE,
    weather_code BIGINT,

    source_file STRING,
    bronze_ingestion_timestamp TIMESTAMP,
    bronze_ingestion_date DATE,

    silver_ingestion_timestamp TIMESTAMP,
    silver_ingestion_date DATE
);

MERGE INTO nyc.nyc_silver.clean_weather_dlt AS target

USING (
    WITH deduplicated_weather AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY timestamp
                ORDER BY bronze_ingestion_timestamp DESC
            ) AS rn

        FROM nyc.nyc_bronze.weather_bronze_dlt

        WHERE timestamp IS NOT NULL
    )

    SELECT
        timestamp,
        temperature_2m,
        precipitation,
        rain,
        snowfall,
        wind_speed_10m,
        weather_code,
        source_file,
        bronze_ingestion_timestamp,
        bronze_ingestion_date,

        current_timestamp() AS silver_ingestion_timestamp,
        current_date() AS silver_ingestion_date

    FROM deduplicated_weather

    WHERE rn = 1

) AS source

ON target.timestamp = source.timestamp

WHEN MATCHED THEN UPDATE SET
    target.temperature_2m = source.temperature_2m,
    target.precipitation = source.precipitation,
    target.rain = source.rain,
    target.snowfall = source.snowfall,
    target.wind_speed_10m = source.wind_speed_10m,
    target.weather_code = source.weather_code,
    target.source_file = source.source_file,
    target.bronze_ingestion_timestamp = source.bronze_ingestion_timestamp,
    target.bronze_ingestion_date = source.bronze_ingestion_date,
    target.silver_ingestion_timestamp = source.silver_ingestion_timestamp,
    target.silver_ingestion_date = source.silver_ingestion_date

WHEN NOT MATCHED THEN INSERT (
    timestamp,
    temperature_2m,
    precipitation,
    rain,
    snowfall,
    wind_speed_10m,
    weather_code,
    source_file,
    bronze_ingestion_timestamp,
    bronze_ingestion_date,
    silver_ingestion_timestamp,
    silver_ingestion_date
)

VALUES (
    source.timestamp,
    source.temperature_2m,
    source.precipitation,
    source.rain,
    source.snowfall,
    source.wind_speed_10m,
    source.weather_code,
    source.source_file,
    source.bronze_ingestion_timestamp,
    source.bronze_ingestion_date,
    source.silver_ingestion_timestamp,
    source.silver_ingestion_date
);