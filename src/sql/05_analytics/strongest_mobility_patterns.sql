-- BUSINESS QUESTION: Which areas show the strongest mobility patterns

SELECT
    l.location_id,
    l.borough,
    l.zone,

    COUNT(f.trip_key) AS pickup_trips,

    ROUND(AVG(f.trip_distance), 2) AS avg_trip_distance,

    ROUND(AVG(f.trip_duration_minutes), 2)
        AS avg_trip_duration_minutes,

    ROUND(SUM(f.total_amount), 2) AS total_revenue

FROM nyc.nyc_gold.fact_taxi_trip_dlt AS f

JOIN nyc.nyc_gold.dim_location AS l
    ON f.PULocationID = l.location_id

GROUP BY
    l.location_id,
    l.borough,
    l.zone

ORDER BY
    pickup_trips DESC
    
    LIMIT 5;

-- MOBILITY OPPORTUNITIES: Identifies areas with lower overall taxi mobility

WITH pickup AS (

    SELECT
        PULocationID AS location_id,
        COUNT(*) AS pickup_trips
    FROM nyc.nyc_gold.fact_taxi_trip_dlt
    GROUP BY PULocationID

),

dropoff AS (

    SELECT
        DOLocationID AS location_id,
        COUNT(*) AS dropoff_trips
    FROM nyc.nyc_gold.fact_taxi_trip_dlt
    GROUP BY DOLocationID

)

SELECT
    l.location_id,
    l.borough,
    l.zone,

    COALESCE(p.pickup_trips, 0) AS pickup_trips,

    COALESCE(d.dropoff_trips, 0) AS dropoff_trips,

    COALESCE(p.pickup_trips, 0)
        + COALESCE(d.dropoff_trips, 0)
        AS total_mobility_activity,

    COALESCE(p.pickup_trips, 0)
        - COALESCE(d.dropoff_trips, 0)
        AS mobility_imbalance

FROM nyc.nyc_gold.dim_location AS l

LEFT JOIN pickup AS p
    ON l.location_id = p.location_id

LEFT JOIN dropoff AS d
    ON l.location_id = d.location_id

ORDER BY
    total_mobility_activity ASC
    
    LIMIT 5;