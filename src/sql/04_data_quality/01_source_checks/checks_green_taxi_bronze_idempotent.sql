-- =====================================================================
-- DATA QUALITY CHECK: Green Taxi Bronze Table
-- =====================================================================
-- Evaluates the ingested Bronze table after deduplication and MERGE.
-- Thresholds: Composite Key & Exact Duplicates <= 1.0% WARN, > 1.0% FAIL
--             Other DQ Areas (Nulls, Lineage, Range) <= 2.0% WARN, > 2.0% FAIL
-- =====================================================================

WITH raw_data AS (
    SELECT 
        *,
        COALESCE(
            REGEXP_EXTRACT(source_file, '(\\d{4}-\\d{2})', 1),
            source_month,
            'UNKNOWN'
        ) AS source_file_month,
        COALESCE(
            DATE_FORMAT(lpep_pickup_datetime, 'yyyy-MM'),
            'UNKNOWN'
        ) AS pickup_date_month
    FROM nyc.nyc_bronze.green_taxi_bronze
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

        -- 3. Audit lineage population check
        COUNT_IF(
            source_file IS NULL 
            OR source_month IS NULL 
            OR bronze_ingestion_timestamp IS NULL 
            OR bronze_ingestion_date IS NULL
        ) AS missing_lineage_count,

        -- 4. Null count for mandatory key fields (7-columns)
        COUNT_IF(
            VendorID IS NULL
            OR lpep_pickup_datetime IS NULL
            OR lpep_dropoff_datetime IS NULL
            OR PULocationID IS NULL
            OR DOLocationID IS NULL
            OR trip_distance IS NULL
            OR total_amount IS NULL
        ) AS null_mandatory_key_fields_count,

        -- 5. Non-positive trip distance (distance <= 0)
        COUNT_IF(trip_distance <= 0) AS non_positive_trip_distance_count,

        -- 6. Negative total amount (amount < 0)
        COUNT_IF(total_amount < 0) AS negative_total_amount_count
    FROM raw_data
),
monthly_source_counts AS (
    SELECT 
        source_file_month,
        COUNT(*) AS month_records
    FROM raw_data
    GROUP BY source_file_month
),
monthly_pickup_counts AS (
    SELECT 
        pickup_date_month,
        COUNT(*) AS month_records
    FROM raw_data
    GROUP BY pickup_date_month
),
dq_results AS (
    -- 1. TOTAL LOADED ROW COUNT
    SELECT 
        1 AS check_order,
        'Total Loaded Row Count' AS check_name,
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

    -- 4. AUDIT LINEAGE POPULATION
    SELECT 
        4,
        'Audit lineage population',
        'LINEAGE',
        total_records,
        missing_lineage_count,
        ROUND((missing_lineage_count * 100.0) / NULLIF(total_records, 0), 2),
        'OTHER_DQ'
    FROM raw_metrics

    UNION ALL

    -- 5. NULL COUNT FOR MANDATORY KEY FIELDS (7-COLUMNS)
    SELECT 
        5,
        'Null count for mandatory key fields (7-columns)',
        'NULL',
        total_records,
        null_mandatory_key_fields_count,
        ROUND((null_mandatory_key_fields_count * 100.0) / NULLIF(total_records, 0), 2),
        'OTHER_DQ'
    FROM raw_metrics

    UNION ALL

    -- 6. NON-POSITIVE TRIP DISTANCE
    SELECT 
        6,
        'Non-positive trip distance',
        'RANGE',
        total_records,
        non_positive_trip_distance_count,
        ROUND((non_positive_trip_distance_count * 100.0) / NULLIF(total_records, 0), 2),
        'OTHER_DQ'
    FROM raw_metrics

    UNION ALL

    -- 7. NEGATIVE TOTAL AMOUNT
    SELECT 
        7,
        'Negative total amount',
        'RANGE',
        total_records,
        negative_total_amount_count,
        ROUND((negative_total_amount_count * 100.0) / NULLIF(total_records, 0), 2),
        'OTHER_DQ'
    FROM raw_metrics

    UNION ALL

    -- 8. MONTHLY ROW COUNT BY SOURCE FILE MONTH
    SELECT 
        10 + DENSE_RANK() OVER (ORDER BY source_file_month ASC) AS check_order,
        CONCAT('Monthly Row Count by Source File Month (', source_file_month, ')') AS check_name,
        'VOLUME' AS check_type,
        month_records AS records_checked,
        0 AS affected_rows,
        0.00 AS failure_pct,
        'MONTHLY_COUNT' AS severity
    FROM monthly_source_counts

    UNION ALL

    -- 9. MONTHLY ROW COUNT BY PICKUP DATE MONTH
    SELECT 
        100 + DENSE_RANK() OVER (ORDER BY pickup_date_month ASC) AS check_order,
        CONCAT('Monthly Row Count by Pickup Date Month (', pickup_date_month, ')') AS check_name,
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