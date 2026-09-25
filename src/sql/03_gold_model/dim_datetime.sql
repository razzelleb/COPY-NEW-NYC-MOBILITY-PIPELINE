-- Create Gold target table for Date/Time dimension
CREATE TABLE IF NOT EXISTS nyc.nyc_gold.dim_datetime (
    datetime_key BIGINT NOT NULL,           -- Primary Key: Sequential BIGINT starting from 1 (0 for unknown)
    full_datetime TIMESTAMP,                -- Full hourly timestamp
    date DATE,                              -- ISO date (YYYY-MM-DD)
    day INT,                                -- Day of month (1 to 31)
    day_name STRING,                        -- Full day name ('Monday', 'Sunday')
    hour INT,                               -- 24-hour scale (0 to 23)
    hour_label STRING,                      -- 12-hour label ('08 AM', '02 PM')
    time_period STRING,                     -- 'Morning', 'Afternoon', 'Evening', 'Night'
    week_of_year INT,                       -- ISO week number (1 to 52)
    month INT,                              -- Month number (1 to 12)
    month_name STRING,                      -- Full month name ('January', 'March')
    quarter INT,                            -- Quarter number (1 to 4)
    year INT,                               -- Calendar year (e.g., 2026)
    is_weekend BOOLEAN,                     -- TRUE for Saturday or Sunday
    is_rush_hour BOOLEAN,                   -- TRUE for weekday peak hours (7–9 AM & 4–7 PM)
    day_of_week INT,                        -- Day index (1 = Sunday to 7 = Saturday)
    gold_ingestion_timestamp TIMESTAMP,     -- Processing timestamp in Gold layer
    gold_ingestion_date DATE                -- Processing date in Gold layer
);

-- Idempotent MERGE INTO execution
MERGE INTO nyc.nyc_gold.dim_datetime AS target
USING (
    WITH hourly_range AS (
        -- Generate hourly sequence for March 2026 through May 2026
        SELECT explode(
            sequence(
                to_timestamp('2026-03-01 00:00:00'), 
                current_timestamp(), 
                interval 1 hour
            )
        ) AS dt
    ),
    calculated_dates AS (
        -- Unknown Member Row (Key = 0)
        SELECT 
            CAST(0 AS BIGINT) AS datetime_key,
            to_timestamp('1900-01-01 00:00:00') AS full_datetime,
            to_date('1900-01-01') AS date,
            0 AS day,
            CAST('Unknown' AS STRING) AS day_name,
            0 AS hour,
            CAST('Unknown' AS STRING) AS hour_label,
            CAST('Unknown' AS STRING) AS time_period,
            0 AS week_of_year,
            0 AS month,
            CAST('Unknown' AS STRING) AS month_name,
            0 AS quarter,
            1900 AS year,
            false AS is_weekend,
            false AS is_rush_hour,
            0 AS day_of_week,
            CAST(current_timestamp() AS TIMESTAMP) AS gold_ingestion_timestamp,
            CAST(current_date() AS DATE) AS gold_ingestion_date

        UNION ALL

        -- Standard Date/Time Transformations (March - May 2026)
        SELECT 
            -- Primary Key (Sequential starting from 1)
            CAST(ROW_NUMBER() OVER (ORDER BY dt) AS BIGINT) AS datetime_key,
            dt AS full_datetime,
            to_date(dt) AS date,
            
            -- Hour & Day Attributes
            dayofmonth(dt) AS day,
            CAST(date_format(dt, 'EEEE') AS STRING) AS day_name,
            hour(dt) AS hour,
            CAST(date_format(dt, 'hh a') AS STRING) AS hour_label,
            
            -- Time Period
            CASE 
                WHEN hour(dt) BETWEEN 5 AND 11 THEN 'Morning'
                WHEN hour(dt) BETWEEN 12 AND 16 THEN 'Afternoon'
                WHEN hour(dt) BETWEEN 17 AND 21 THEN 'Evening'
                ELSE 'Night'
            END AS time_period,

            -- Calendar Parts
            weekofyear(dt) AS week_of_year,
            month(dt) AS month,
            CAST(date_format(dt, 'MMMM') AS STRING) AS month_name,
            quarter(dt) AS quarter,
            year(dt) AS year,

            -- Flags & Indicators
            CASE WHEN dayofweek(dt) IN (1, 7) THEN true ELSE false END AS is_weekend,
            CASE WHEN dayofweek(dt) BETWEEN 2 AND 6 AND hour(dt) IN (7, 8, 9, 16, 17, 18, 19) THEN true ELSE false END AS is_rush_hour,
            dayofweek(dt) AS day_of_week,

            -- Audit Metadata (Gold Layer Execution)
            CAST(current_timestamp() AS TIMESTAMP) AS gold_ingestion_timestamp,
            CAST(current_date() AS DATE) AS gold_ingestion_date
        FROM hourly_range
    )
    SELECT * FROM calculated_dates
) AS source
-- Match on actual timestamp to preserve assigned sequential keys
ON target.full_datetime = source.full_datetime

WHEN MATCHED THEN UPDATE SET
    target.datetime_key = source.datetime_key,
    target.date = source.date,
    target.day = source.day,
    target.day_name = source.day_name,
    target.hour = source.hour,
    target.hour_label = source.hour_label,
    target.time_period = source.time_period,
    target.week_of_year = source.week_of_year,
    target.month = source.month,
    target.month_name = source.month_name,
    target.quarter = source.quarter,
    target.year = source.year,
    target.is_weekend = source.is_weekend,
    target.is_rush_hour = source.is_rush_hour,
    target.day_of_week = source.day_of_week,
    target.gold_ingestion_timestamp = source.gold_ingestion_timestamp,
    target.gold_ingestion_date = source.gold_ingestion_date

WHEN NOT MATCHED THEN INSERT (
    datetime_key,
    full_datetime,
    date,
    day,
    day_name,
    hour,
    hour_label,
    time_period,
    week_of_year,
    month,
    month_name,
    quarter,
    year,
    is_weekend,
    is_rush_hour,
    day_of_week,
    gold_ingestion_timestamp,
    gold_ingestion_date
) VALUES (
    source.datetime_key,
    source.full_datetime,
    source.date,
    source.day,
    source.day_name,
    source.hour,
    source.hour_label,
    source.time_period,
    source.week_of_year,
    source.month,
    source.month_name,
    source.quarter,
    source.year,
    source.is_weekend,
    source.is_rush_hour,
    source.day_of_week,
    source.gold_ingestion_timestamp,
    source.gold_ingestion_date
);
