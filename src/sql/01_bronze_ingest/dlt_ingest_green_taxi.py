import dlt
from pyspark.sql import functions as F

# =====================================================================
# GREEN TAXI BRONZE INGESTION (DELTA LIVE TABLES - PYSPARK)
# Incremental ingestion via Auto Loader & idempotent CDC via apply_changes
# =====================================================================

# Temporary Staging Table (Internal stream; NOT published to Unity Catalog)
@dlt.table(
    name="green_taxi_raw_staging",
    temporary=True,
    comment="Internal streaming staging table for raw Green Taxi Parquet files"
)
def green_taxi_raw_staging():
    return (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "parquet")
        .option("cloudFiles.schemaLocation", "/Volumes/nyc/default/nyc-mobility-volume/_schemas/green_taxi")
        .load("/Volumes/nyc/default/nyc-mobility-volume/green_taxi/")
        .select(
            "*",
            F.col("_metadata.file_name").alias("source_file"),
            F.date_format(F.col("lpep_pickup_datetime"), "yyyy-MM").alias("source_month"),
            F.current_timestamp().alias("bronze_ingestion_timestamp"),
            F.current_date().alias("bronze_ingestion_date")
        )
    )

# Target Streaming Table Declaration (nyc.nyc_bronze.green_taxi_bronze)
dlt.create_streaming_table(
    name="green_taxi_bronze",
    comment="Idempotent Bronze Green Taxi table deduplicated by composite natural key"
)

# Idempotent CDC Upsert (Guarantees safe reruns with 0 duplicates)
dlt.apply_changes(
    target="green_taxi_bronze",
    source="green_taxi_raw_staging",
    keys=[
        "VendorID",
        "lpep_pickup_datetime",
        "lpep_dropoff_datetime",
        "PULocationID",
        "DOLocationID",
        "trip_distance",
        "total_amount"
    ],
    sequence_by="bronze_ingestion_timestamp",
    stored_as_scd_type="1"
)