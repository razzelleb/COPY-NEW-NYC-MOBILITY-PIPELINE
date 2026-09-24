-- Evaluation track for dlt comparison; see doc/sources/open_meteo_dlt.md
-- Same logic as dim_weather.sql, sourced from the dlt-based Silver table.

CREATE TABLE IF NOT EXISTS nyc.nyc_gold.dim_weather_dlt (
    weather_key BIGINT GENERATED ALWAYS AS IDENTITY,
    weather_datetime TIMESTAMP,

    temperature_2m DOUBLE,
    precipitation DOUBLE,
    rain DOUBLE,
    snowfall DOUBLE,
    wind_speed_10m DOUBLE,
    weather_code INT,
    weather_condition STRING,

    silver_ingestion_timestamp TIMESTAMP,
    silver_ingestion_date DATE,

    gold_ingestion_timestamp TIMESTAMP,
    gold_ingestion_date DATE
);

MERGE INTO nyc.nyc_gold.dim_weather_dlt AS target

USING (

    WITH deduplicated_weather AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY timestamp
                ORDER BY silver_ingestion_timestamp DESC
            ) AS row_num

        FROM nyc.nyc_silver.clean_weather_dlt

        WHERE timestamp IS NOT NULL
    )

    SELECT
        timestamp AS weather_datetime,

        temperature_2m,
        precipitation,
        rain,
        snowfall,
        wind_speed_10m,
        CAST(weather_code AS INT) AS weather_code,

        CASE weather_code
            WHEN 0 THEN 'Clear sky'
            WHEN 1 THEN 'Mainly clear'
            WHEN 2 THEN 'Partly cloudy'
            WHEN 3 THEN 'Overcast'
            WHEN 45 THEN 'Fog'
            WHEN 48 THEN 'Depositing rime fog'
            WHEN 51 THEN 'Light drizzle'
            WHEN 53 THEN 'Moderate drizzle'
            WHEN 55 THEN 'Dense drizzle'
            WHEN 56 THEN 'Light freezing drizzle'
            WHEN 57 THEN 'Dense freezing drizzle'
            WHEN 61 THEN 'Slight rain'
            WHEN 63 THEN 'Moderate rain'
            WHEN 65 THEN 'Heavy rain'
            WHEN 66 THEN 'Light freezing rain'
            WHEN 67 THEN 'Heavy freezing rain'
            WHEN 71 THEN 'Slight snowfall'
            WHEN 73 THEN 'Moderate snowfall'
            WHEN 75 THEN 'Heavy snowfall'
            WHEN 77 THEN 'Snow grains'
            WHEN 80 THEN 'Slight rain showers'
            WHEN 81 THEN 'Moderate rain showers'
            WHEN 82 THEN 'Violent rain showers'
            WHEN 85 THEN 'Slight snow showers'
            WHEN 86 THEN 'Heavy snow showers'
            WHEN 95 THEN 'Thunderstorm'
            WHEN 96 THEN 'Thunderstorm with slight hail'
            WHEN 99 THEN 'Thunderstorm with heavy hail'
            ELSE 'Unknown'
        END AS weather_condition,

        silver_ingestion_timestamp,
        silver_ingestion_date,

        current_timestamp() AS gold_ingestion_timestamp,
        current_date() AS gold_ingestion_date

    FROM deduplicated_weather

    WHERE row_num = 1

) AS source

ON target.weather_datetime = source.weather_datetime

WHEN MATCHED THEN UPDATE SET
    target.temperature_2m = source.temperature_2m,
    target.precipitation = source.precipitation,
    target.rain = source.rain,
    target.snowfall = source.snowfall,
    target.wind_speed_10m = source.wind_speed_10m,
    target.weather_code = source.weather_code,
    target.weather_condition = source.weather_condition,

    target.silver_ingestion_timestamp = source.silver_ingestion_timestamp,
    target.silver_ingestion_date = source.silver_ingestion_date,

    target.gold_ingestion_timestamp = source.gold_ingestion_timestamp,
    target.gold_ingestion_date = source.gold_ingestion_date

WHEN NOT MATCHED THEN INSERT (
    weather_datetime,
    temperature_2m,
    precipitation,
    rain,
    snowfall,
    wind_speed_10m,
    weather_code,
    weather_condition,

    silver_ingestion_timestamp,
    silver_ingestion_date,

    gold_ingestion_timestamp,
    gold_ingestion_date
)

VALUES (
    source.weather_datetime,
    source.temperature_2m,
    source.precipitation,
    source.rain,
    source.snowfall,
    source.wind_speed_10m,
    source.weather_code,
    source.weather_condition,

    source.silver_ingestion_timestamp,
    source.silver_ingestion_date,

    source.gold_ingestion_timestamp,
    source.gold_ingestion_date
);