from delta.tables import DeltaTable
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.getOrCreate()

BRONZE_TABLE = "nyc.nyc_bronze.green_taxi_bronze"
VOLUME_DIR = "/Volumes/nyc/default/nyc-mobility-volume/green_taxi/"


def ensure_bronze_table_exists():
  """Ensures Bronze Delta table exists with the required schema and metadata fields."""
  spark.sql(f"""
        CREATE TABLE IF NOT EXISTS {BRONZE_TABLE} (
            VendorID INT,
            lpep_pickup_datetime TIMESTAMP,
            lpep_dropoff_datetime TIMESTAMP,
            store_and_fwd_flag STRING,
            RatecodeID BIGINT,
            PULocationID INT,
            DOLocationID INT,
            passenger_count BIGINT,
            trip_distance DOUBLE,
            fare_amount DOUBLE,
            extra DOUBLE,
            mta_tax DOUBLE,
            tip_amount DOUBLE,
            tolls_amount DOUBLE,
            ehail_fee DOUBLE,
            improvement_surcharge DOUBLE,
            total_amount DOUBLE,
            payment_type BIGINT,
            trip_type BIGINT,
            congestion_surcharge DOUBLE,
            cbd_congestion_fee DOUBLE,
            source_file STRING,
            source_month STRING,
            bronze_ingestion_timestamp TIMESTAMP,
            bronze_ingestion_date DATE
        ) USING DELTA
    """)


def ingest_green_taxi_auto():
  """Scans all Parquet files in the Volume and merges them idempotently into Bronze without defining months."""
  ensure_bronze_table_exists()

  # READ ALL PARQUET FILES AUTOMATICALLY & CAPTURE FILE NAME
  df_raw = spark.read.parquet(f"{VOLUME_DIR}*.parquet").select(
      "*", "_metadata.file_name"
  )

  # DYNAMICALLY EXTRACT source_month & ADD LINEAGE METADATA
  df_staging = (
      df_raw.withColumn("source_file", F.col("file_name"))
      .withColumn(
          "source_month",
          F.date_format(F.col("lpep_pickup_datetime"), "yyyy-MM"),
      )
      .withColumn("bronze_ingestion_timestamp", F.current_timestamp())
      .withColumn("bronze_ingestion_date", F.current_date())
      .drop("file_name")
  )

  # 3. DEDUPLICATE STAGING RECORDS ON COMPOSITE NATURAL KEY
  composite_key = [
      "VendorID",
      "lpep_pickup_datetime",
      "lpep_dropoff_datetime",
      "PULocationID",
      "DOLocationID",
      "trip_distance",
      "total_amount",
  ]

  window_spec = Window.partitionBy(*composite_key).orderBy(
      F.col("lpep_pickup_datetime").desc()
  )

  df_dedup = (
      df_staging.withColumn("row_num", F.row_number().over(window_spec))
      .filter(F.col("row_num") == 1)
      .drop("row_num")
  )

  # 4. IDEMPOTENT MERGE INTO DELTA TABLE
  bronze_delta = DeltaTable.forName(spark, BRONZE_TABLE)

  merge_condition = """
        target.VendorID <=> source.VendorID
        AND target.lpep_pickup_datetime <=> source.lpep_pickup_datetime
        AND target.lpep_dropoff_datetime <=> source.lpep_dropoff_datetime
        AND target.PULocationID <=> source.PULocationID
        AND target.DOLocationID <=> source.DOLocationID
        AND target.trip_distance <=> source.trip_distance
        AND target.total_amount <=> source.total_amount
        AND target.source_month <=> source.source_month
    """

  (
      bronze_delta.alias("target")
      .merge(df_dedup.alias("source"), merge_condition)
      .whenMatchedUpdateAll()
      .whenNotMatchedInsertAll()
      .execute()
  )

  print(f"[SUCCESS] Auto-ingested available files idempotently into {BRONZE_TABLE}.")


if __name__ == "__main__":
  ingest_green_taxi_auto()