-- =====================================================================
-- DATA QUALITY CHECK: Raw Downloaded Green Taxi Parquet Files
-- =====================================================================
-- Evaluates raw downloaded files in the Volume prior to Bronze loading.
-- Order:
--   1. Total Downloaded Row Count (Overall)
--   2. Duplicate Records Check
--   3. Other Quality Checks (Nulls, Non-essential fields)
--   4. Monthly Row Count by Source Month (File Lineage) -> PASS
--   5. Monthly Row Count by Pickup Date (Taximeter Timestamp) -> PASS
-- =====================================================================

WITH raw_parquet AS (
    SELECT 
        *,
        -- Extract Source Month from raw file name metadata
        COALESCE(
            REGEXP_EXTRACT(_metadata.file_name, '(\\d{4}-\\d{2})', 1),
            'UNKNOWN'
        ) AS source_month,
        -- Extract Pickup Month from trip pickup timestamp
        COALESCE(
            DATE_FORMAT(lpep_pickup_datetime, 'yyyy-MM'),
            'UNKNOWN'
        ) AS pickup_month
    FROM parquet.`/Volumes/nyc/default/nyc-mobility-volume/green_taxi/*.parquet`
),

raw_metrics AS (
    SELECT 
        COUNT(*) AS total_records,

        -- Duplicate records check on 7-column composite natural key
        COUNT(*) - COUNT(DISTINCT STRUCT(
            VendorID,
            lpep_pickup_datetime,
            lpep_dropoff_datetime,
            PULocationID,
            DOLocationID,
            trip_distance,
            total_amount
        )) AS duplicate_trip_count,

        -- Essential fields null check
        COUNT_IF(
            lpep_pickup_datetime IS NULL
            OR lpep_dropoff_datetime IS NULL
            OR PULocationID IS NULL
            OR DOLocationID IS NULL
        ) AS missing_essential_fields_count,

        -- Non-essential column null check (ehail_fee)
        COUNT_IF(ehail_fee IS NULL) AS null_ehail_fee_count
    FROM raw_parquet
),

monthly_source_counts AS (
    -- Group by File Source Month
    SELECT 
        source_month,
        COUNT(*) AS month_records
    FROM raw_parquet
    GROUP BY source_month
),

monthly_pickup_counts AS (
    -- Group by Pickup Date Timestamp Month
    SELECT 
        pickup_month,
        COUNT(*) AS month_records
    FROM raw_parquet
    GROUP BY pickup_month
),

dq_results AS (
    -- 1. TOTAL DOWNLOADED ROW COUNT
    SELECT 
        1 AS check_order,
        'Total Downloaded Row Count' AS check_name,
        'VOLUME' AS check_type,
        total_records AS records_checked,
        0 AS affected_rows,
        0.00 AS failure_pct,
        'CRITICAL' AS severity
    FROM raw_metrics

    UNION ALL

    -- 2. DUPLICATE RECORDS CHECK
    SELECT 
        2,
        'Duplicate Records Check',
        'UNIQUE',
        total_records,
        duplicate_trip_count,
        ROUND((duplicate_trip_count * 100.0) / NULLIF(total_records, 0), 2),
        'CRITICAL'
    FROM raw_metrics

    UNION ALL

    -- 3. MISSING ESSENTIAL FIELDS NULL CHECK
    SELECT 
        3,
        'Missing Essential Fields Null Check',
        'NULL',
        total_records,
        missing_essential_fields_count,
        ROUND((missing_essential_fields_count * 100.0) / NULLIF(total_records, 0), 2),
        'CRITICAL'
    FROM raw_metrics

    UNION ALL

    -- 4. NON-ESSENTIAL COLUMN NULL CHECK (ehail_fee)
    SELECT 
        4,
        'Non-Essential Column Null Check (ehail_fee)',
        'NULL',
        total_records,
        null_ehail_fee_count,
        ROUND((null_ehail_fee_count * 100.0) / NULLIF(total_records, 0), 2),
        'NON_ESSENTIAL'
    FROM raw_metrics

    UNION ALL

    -- 5. MONTHLY ROW COUNT BY SOURCE MONTH (FILE LINEAGE)
    SELECT 
        10 + DENSE_RANK() OVER (ORDER BY source_month ASC) AS check_order,
        CONCAT('Monthly Row Count by Source Month (', source_month, ')') AS check_name,
        'VOLUME' AS check_type,
        month_records AS records_checked,
        0 AS affected_rows,
        0.00 AS failure_pct,
        'MONTHLY_COUNT' AS severity
    FROM monthly_source_counts

    UNION ALL

    -- 6. MONTHLY ROW COUNT BY PICKUP DATE (TAXIMETER TIMESTAMP)
    SELECT 
        100 + DENSE_RANK() OVER (ORDER BY pickup_month ASC) AS check_order,
        CONCAT('Monthly Row Count by Pickup Date (', pickup_month, ')') AS check_name,
        'VOLUME' AS check_type,
        month_records AS records_checked,
        0 AS affected_rows,
        0.00 AS failure_pct,
        'MONTHLY_COUNT' AS severity
    FROM monthly_pickup_counts
)

SELECT 
    check_name,
    check_type,
    records_checked,
    affected_rows,
    CONCAT(failure_pct, '%') AS affected_percentage,
    CASE 
        WHEN severity = 'MONTHLY_COUNT' THEN 'PASS'
        WHEN affected_rows = 0 THEN 'PASS'
        WHEN severity = 'NON_ESSENTIAL' THEN 'WARN'
        WHEN failure_pct <= 5.00 THEN 'WARN'
        ELSE 'FAIL'
    END AS status
FROM dq_results
ORDER BY check_order ASC;