-- =====================================================================
-- DATA QUALITY CHECK: Raw Downloaded Green Taxi Parquet Files
-- =====================================================================
-- Evaluates raw downloaded files in the Volume prior to Bronze loading.
-- Thresholds: Composite Key & Exact Duplicates <= 1.0% WARN, > 1.0% FAIL
--             Mandatory Key Field Nulls <= 2.0% WARN, > 2.0% FAIL
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

        -- 1. Duplicate composite key check (7-columns)
        COUNT(*) - COUNT(DISTINCT STRUCT(
            VendorID,
            lpep_pickup_datetime,
            lpep_dropoff_datetime,
            PULocationID,
            DOLocationID,
            trip_distance,
            total_amount
        )) AS duplicate_composite_key_count,

        -- 2. Exact duplicate rows (all columns identical)
        COUNT(*) - COUNT(DISTINCT STRUCT(*)) AS exact_duplicate_rows_count,

        -- 3. Null count for mandatory key fields (7-columns)
        COUNT_IF(
            VendorID IS NULL
            OR lpep_pickup_datetime IS NULL
            OR lpep_dropoff_datetime IS NULL
            OR PULocationID IS NULL
            OR DOLocationID IS NULL
            OR trip_distance IS NULL
            OR total_amount IS NULL
        ) AS null_mandatory_key_fields_count
    FROM raw_parquet
),
monthly_source_counts AS (
    SELECT 
        source_month,
        COUNT(*) AS month_records
    FROM raw_parquet
    GROUP BY source_month
),
monthly_pickup_counts AS (
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

    -- 2. DUPLICATE COMPOSITE KEY CHECK (7-COLUMNS)
    SELECT 
        2,
        'Duplicate composite key check (7-columns)',
        'UNIQUE',
        total_records,
        duplicate_composite_key_count,
        ROUND((duplicate_composite_key_count * 100.0) / NULLIF(total_records, 0), 2),
        'COMPOSITE_KEY'
    FROM raw_metrics

    UNION ALL

    -- 3. EXACT DUPLICATE ROWS
    SELECT 
        3,
        'Exact duplicate rows',
        'UNIQUE',
        total_records,
        exact_duplicate_rows_count,
        ROUND((exact_duplicate_rows_count * 100.0) / NULLIF(total_records, 0), 2),
        'COMPOSITE_KEY'
    FROM raw_metrics

    UNION ALL

    -- 4. NULL COUNT FOR MANDATORY KEY FIELDS (7-COLUMNS)
    SELECT 
        4,
        'Null count for mandatory key fields (7-columns)',
        'NULL',
        total_records,
        null_mandatory_key_fields_count,
        ROUND((null_mandatory_key_fields_count * 100.0) / NULLIF(total_records, 0), 2),
        'OTHER_DQ'
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
        WHEN severity = 'COMPOSITE_KEY' AND failure_pct <= 1.00 THEN 'WARN'
        WHEN severity = 'COMPOSITE_KEY' AND failure_pct > 1.00 THEN 'FAIL'
        WHEN severity = 'OTHER_DQ' AND failure_pct <= 2.00 THEN 'WARN'
        WHEN severity = 'OTHER_DQ' AND failure_pct > 2.00 THEN 'FAIL'
        ELSE 'FAIL'
    END AS status
FROM dq_results
ORDER BY check_order ASC;