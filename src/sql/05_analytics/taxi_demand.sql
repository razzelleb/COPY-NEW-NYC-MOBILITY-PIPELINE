-- When is taxi demand highest?
-- Aggregates taxi trips by day of the week and hour.
SELECT 
    d.day_name,
    d.hour,
    COUNT(f.trip_key) AS trip_count
FROM nyc.nyc_gold.fact_taxi_trip_dlt f
JOIN nyc.nyc_gold.dim_datetime d
    ON f.pickup_datetime_key = d.datetime_key
GROUP BY 
    d.day_name,
    d.hour,
    d.day_of_week
ORDER BY 
    d.day_of_week,
    d.hour;


-- Where is taxi demand highest?
-- Aggregates taxi trips by pickup zone and borough
SELECT 
    l.zone,
    l.borough,
    COUNT(*) AS trip_count
FROM nyc.nyc_gold.fact_taxi_trip_dlt f
JOIN nyc.nyc_gold.dim_location l
    ON f.pickup_location_key = l.location_key
GROUP BY 
    l.zone, 
    l.borough
ORDER BY 
    trip_count DESC;
