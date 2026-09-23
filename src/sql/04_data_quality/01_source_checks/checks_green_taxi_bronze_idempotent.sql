-- =====================================================================
-- DATA QUALITY CHECK: Green Taxi Bronze Delta Table
-- =====================================================================
-- Evaluates the ingested Bronze table after deduplication and MERGE.
-- Order:
--   1. Total Loaded Row Count (Overall)
--   2. Duplicate Trips Check
--   3. Other Quality Checks (Lineage, Nulls, Duration Logic, Ranges)
--   4. Monthly Row Count by Source File Month (File Lineage) -> PASS
--   5. Monthly Row Count by Pickup Date Month (Taximeter Timestamp) -> PASS
-- =====================================================================

WITH raw_data AS (
    SELECT 
        *,
        -- Source File Month: Extracted directly from the source_file column where the row originated
        COALESCE(
            REGEXP_EXTRACT(source_file, '(\\d{4}-\\d{2})', 1),
            source_month,
            'UNKNOWN'
        ) AS source_file_month,

        -- Pickup Date Month: Extracted from trip pickup timestamp
        COALESCE(
            DATE_FORMAT(lpep_pickup_datetime, 'yyyy-MM'),
            'UNKNOWN'
        ) AS pickup_date_month
    FROM nyc.nyc_bronze.green_taxi_bronze
),

raw_metrics AS (
    SELECT 
        COUNT(*) AS total_records,

        -- Duplicate trips check on 7-column composite natural key
        COUNT(*) - COUNT(DISTINCT STRUCT(
            VendorID,
            lpep_pickup_datetime,
            lpep_dropoff_datetime,
            PULocationID,
            DOLocationID,
            trip_distance,
            total_amount
        )) AS duplicate_trip_count,

        -- Audit lineage metadata null check
        COUNT_IF(
            source_file IS NULL 
            OR source_month IS NULL 
            OR bronze_ingestion_timestamp IS NULL 
            OR bronze_ingestion_date IS NULL
        ) AS missing_lineage_count,

        -- Mandatory key fields null check
        COUNT_IF(
            lpep_pickup_datetime IS NULL
            OR lpep_dropoff_datetime IS NULL
            OR PULocationID IS NULL
            OR DOLocationID IS NULL
        ) AS missing_mandatory_keys_count,

        -- Trip duration logic check
        COUNT_IF(lpep_dropoff_datetime < lpep_pickup_datetime) AS invalid_trip_duration_count,

        -- Value range sanity checks
        COUNT_IF(trip_distance <= 0) AS invalid_distance_count,
        COUNT_IF(total_amount < 0) AS negative_total_amount_count
    FROM raw_data
),

monthly_source_counts AS (
    -- Group by File Source Batch (Where the row came from)
    SELECT 
        source_file_month,
        COUNT(*) AS month_records
    FROM raw_data
    GROUP BY source_file_month
),

monthly_pickup_counts AS (
    -- Group by Taximeter Pickup Date
    SELECT 
        pickup_date_month,
        COUNT(*) AS month_records
    FROM raw_data
    GROUP BY pickup_date_month
),

dq_results AS (
    -- 1. TOTAL LOADED ROW COUNT (OVERALL)
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

    -- 2. DUPLICATE TRIPS CHECK
    SELECT 
        2,
        'Duplicate Trips Check',
        'UNIQUE',
        total_records,
        duplicate_trip_count,
        ROUND((duplicate_trip_count * 100.0) / NULLIF(total_records, 0), 2),
        'CRITICAL'
    FROM raw_metrics

    UNION ALL

    -- 3. INGESTION AUDIT LINEAGE POPULATION
    SELECT 
        3,
        'Ingestion Audit Lineage Population',
        'LINEAGE',
        total_records,
        missing_lineage_count,
        ROUND((missing_lineage_count * 100.0) / NULLIF(total_records, 0), 2),
        'CRITICAL'
    FROM raw_metrics

    UNION ALL

    -- 4. MISSING MANDATORY KEY FIELDS
    SELECT 
        4,
        'Missing Mandatory Key Fields',
        'NULL',
        total_records,
        missing_mandatory_keys_count,
        ROUND((missing_mandatory_keys_count * 100.0) / NULLIF(total_records, 0), 2),
        'CRITICAL'
    FROM raw_metrics

    UNION ALL

    -- 5. INVALID TRIP DURATION
    SELECT 
        5,
        'Invalid Trip Duration (Dropoff < Pickup)',
        'LOGIC',
        total_records,
        invalid_trip_duration_count,
        ROUND((invalid_trip_duration_count * 100.0) / NULLIF(total_records, 0), 2),
        'CRITICAL'
    FROM raw_metrics

    UNION ALL

    -- 6. NON-POSITIVE TRIP DISTANCE
    SELECT 
        6,
        'Non-Positive Trip Distance',
        'RANGE',
        total_records,
        invalid_distance_count,
        ROUND((invalid_distance_count * 100.0) / NULLIF(total_records, 0), 2),
        'CRITICAL'
    FROM raw_metrics

    UNION ALL

    -- 7. NEGATIVE TOTAL AMOUNT
    SELECT 
        7,
        'Negative Total Amount',
        'RANGE',
        total_records,
        negative_total_amount_count,
        ROUND((negative_total_amount_count * 100.0) / NULLIF(total_records, 0), 2),
        'CRITICAL'
    FROM raw_metrics

    UNION ALL

    -- 8. MONTHLY ROW COUNT BY SOURCE FILE MONTH (FILE LINEAGE) -> PASS
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

    -- 9. MONTHLY ROW COUNT BY PICKUP DATE MONTH (TAXIMETER TIMESTAMP) -> PASS
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
        WHEN severity = 'NON_ESSENTIAL' THEN 'WARN'
        WHEN failure_pct <= 5.00 THEN 'WARN'
        ELSE 'FAIL'
    END AS status
FROM dq_results
ORDER BY check_order ASC;