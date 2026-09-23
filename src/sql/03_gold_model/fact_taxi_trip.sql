CREATE TABLE IF NOT EXISTS nyc.nyc_gold.fact_taxi_trip (
    trip_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    vendor_id INT,
    ratecode_id BIGINT,
    store_and_fwd_flag STRING,
    trip_type BIGINT,

    pickup_datetime_key BIGINT,    -- FK -> dim_datetime.datetime_key
    dropoff_datetime_key BIGINT,   -- FK -> dim_datetime.datetime_key
    pickup_location_key BIGINT,    -- FK -> dim_location.location_key
    dropoff_location_key BIGINT,   -- FK -> dim_location.location_key
    weather_key BIGINT,            -- FK -> dim_weather_dlt.weather_key

    -- Kept for MERGE matching / duration calc — NOT surrogate keys,
    -- but the actual values that distinguish one trip from another.
    -- See note below on why surrogate keys alone can't be the MERGE key here.
    lpep_pickup_datetime TIMESTAMP,
    lpep_dropoff_datetime TIMESTAMP,
    PULocationID INT,
    DOLocationID INT,

    payment_type BIGINT,
    passenger_count BIGINT,
    trip_distance DOUBLE,
    trip_duration_minutes DOUBLE,
    fare_amount DOUBLE,
    extra DOUBLE,
    mta_tax DOUBLE,
    tip_amount DOUBLE,
    tolls_amount DOUBLE,
    ehail_fee DOUBLE,
    improvement_surcharge DOUBLE,
    congestion_surcharge DOUBLE,
    cbd_congestion_fee DOUBLE,
    total_amount DOUBLE,

    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE
);

MERGE INTO nyc.nyc_gold.fact_taxi_trip AS target
USING (
    SELECT
        s.VendorID AS vendor_id,
        s.RatecodeID AS ratecode_id,
        s.store_and_fwd_flag,
        s.trip_type,

        dt_pu.datetime_key AS pickup_datetime_key,
        dt_do.datetime_key AS dropoff_datetime_key,
        dl_pu.location_key AS pickup_location_key,
        dl_do.location_key AS dropoff_location_key,
        dw.weather_key,

        s.lpep_pickup_datetime,
        s.lpep_dropoff_datetime,
        s.PULocationID,
        s.DOLocationID,

        s.payment_type,
        s.passenger_count,
        s.trip_distance,

        ROUND(
            (unix_timestamp(s.lpep_dropoff_datetime) - unix_timestamp(s.lpep_pickup_datetime)) / 60.0,
        2) AS trip_duration_minutes,

        s.fare_amount, s.extra, s.mta_tax, s.tip_amount, s.tolls_amount, s.ehail_fee,
        s.improvement_surcharge, s.congestion_surcharge, s.cbd_congestion_fee, s.total_amount,

        current_timestamp() AS gold_processed_timestamp,
        current_date() AS gold_processed_date

    FROM nyc.nyc_silver.green_taxi_silver AS s

    INNER JOIN nyc.nyc_gold.dim_datetime AS dt_pu
        ON date_trunc('hour', s.lpep_pickup_datetime) = dt_pu.full_datetime

    INNER JOIN nyc.nyc_gold.dim_datetime AS dt_do
        ON date_trunc('hour', s.lpep_dropoff_datetime) = dt_do.full_datetime

    INNER JOIN nyc.nyc_gold.dim_location AS dl_pu
        ON s.PULocationID = dl_pu.location_id

    INNER JOIN nyc.nyc_gold.dim_location AS dl_do
        ON s.DOLocationID = dl_do.location_id

    LEFT JOIN nyc.nyc_gold.dim_weather_dlt AS dw
        ON date_trunc('hour', s.lpep_pickup_datetime) = dw.weather_datetime

) AS source

-- Matches on the REAL trip-distinguishing values, not surrogate keys —
-- taxi trips routinely share the same hour+zone combo,
-- so surrogate keys alone are not unique at this fact grain.
ON  target.vendor_id             <=> source.vendor_id
AND target.lpep_pickup_datetime  <=> source.lpep_pickup_datetime
AND target.lpep_dropoff_datetime <=> source.lpep_dropoff_datetime
AND target.PULocationID          <=> source.PULocationID
AND target.DOLocationID          <=> source.DOLocationID
AND target.trip_distance         <=> source.trip_distance
AND target.total_amount          <=> source.total_amount

WHEN MATCHED THEN UPDATE SET
    target.pickup_datetime_key = source.pickup_datetime_key,
    target.dropoff_datetime_key = source.dropoff_datetime_key,
    target.pickup_location_key = source.pickup_location_key,
    target.dropoff_location_key = source.dropoff_location_key,
    target.weather_key = source.weather_key,
    target.ratecode_id = source.ratecode_id,
    target.store_and_fwd_flag = source.store_and_fwd_flag,
    target.trip_type = source.trip_type,
    target.payment_type = source.payment_type,
    target.passenger_count = source.passenger_count,
    target.trip_duration_minutes = source.trip_duration_minutes,
    target.fare_amount = source.fare_amount,
    target.extra = source.extra,
    target.mta_tax = source.mta_tax,
    target.tip_amount = source.tip_amount,
    target.tolls_amount = source.tolls_amount,
    target.ehail_fee = source.ehail_fee,
    target.improvement_surcharge = source.improvement_surcharge,
    target.congestion_surcharge = source.congestion_surcharge,
    target.cbd_congestion_fee = source.cbd_congestion_fee,
    target.total_amount = source.total_amount,
    target.gold_processed_timestamp = source.gold_processed_timestamp,
    target.gold_processed_date = source.gold_processed_date

WHEN NOT MATCHED THEN INSERT (
    pickup_datetime_key, dropoff_datetime_key, pickup_location_key, dropoff_location_key, weather_key,
    vendor_id, ratecode_id, store_and_fwd_flag, trip_type,
    lpep_pickup_datetime, lpep_dropoff_datetime, PULocationID, DOLocationID,
    payment_type, passenger_count, trip_distance, trip_duration_minutes,
    fare_amount, extra, mta_tax, tip_amount, tolls_amount, ehail_fee,
    improvement_surcharge, congestion_surcharge, cbd_congestion_fee, total_amount,
    gold_processed_timestamp, gold_processed_date
) VALUES (
    source.pickup_datetime_key, source.dropoff_datetime_key, source.pickup_location_key, source.dropoff_location_key, source.weather_key,
    source.vendor_id, source.ratecode_id, source.store_and_fwd_flag, source.trip_type,
    source.lpep_pickup_datetime, source.lpep_dropoff_datetime, source.PULocationID, source.DOLocationID,
    source.payment_type, source.passenger_count, source.trip_distance, source.trip_duration_minutes,
    source.fare_amount, source.extra, source.mta_tax, source.tip_amount, source.tolls_amount, source.ehail_fee,
    source.improvement_surcharge, source.congestion_surcharge, source.cbd_congestion_fee, source.total_amount,
    source.gold_processed_timestamp, source.gold_processed_date
);