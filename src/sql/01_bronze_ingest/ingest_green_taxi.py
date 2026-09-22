import dlt
from pathlib import Path
from datetime import datetime
import pandas as pd
from pyspark.sql import SparkSession

# Initialize Spark Session & enable Delta schema auto-merge
spark = SparkSession.builder.getOrCreate()
spark.conf.set("spark.databricks.delta.schema.autoMerge.enabled", "true")

# Volume path containing raw Parquet files
VOLUME_PATH = Path("/Volumes/nyc/default/nyc-mobility-volume/green_taxi/")

# Define dlt resource with MERGE write disposition and 7-column composite primary key
@dlt.resource(
    name="green_taxi_bronze",
    write_disposition="merge",
    primary_key=[
        "VendorID",
        "lpep_pickup_datetime",
        "lpep_dropoff_datetime",
        "PULocationID",
        "DOLocationID",
        "trip_distance",
        "total_amount"
    ]
)
def green_taxi_resource(selected_month=None):
    """
    Reads Green Taxi Parquet files from the volume and appends bronze lineage metadata.
    Pass selected_month (e.g., '2026-03') to load a specific month for incremental testing.
    """
    pattern = f"green_tripdata_{selected_month}.parquet" if selected_month else "*.parquet"
    files = list(VOLUME_PATH.glob(pattern))

    if not files:
        print(f"No files found matching pattern: {pattern}")
        return

    for file_path in files:
        print(f"Processing file: {file_path.name}")
        df = pd.read_parquet(file_path)
        
        # Add Lineage & Ingestion Metadata
        df["source_file"] = file_path.name
        df["source_month"] = pd.to_datetime(df["lpep_pickup_datetime"]).dt.strftime("%Y-%m")
        df["bronze_ingestion_timestamp"] = datetime.now()
        df["bronze_ingestion_date"] = datetime.now().date()
        
        # Yield dict records to dlt pipeline
        yield df.to_dict(orient="records")

# Create dlt pipeline targeting Databricks Delta Lake
pipeline = dlt.pipeline(
    pipeline_name="green_taxi_ingestion",
    destination="databricks",
    dataset_name="nyc_bronze"
)

# Main execution entry point
if __name__ == "__main__":
    # Set selected_month to test specific months (e.g., "2026-03", "2026-04", "2026-05")
    # Set selected_month=None to process all parquet files in the volume.
    TEST_MONTH = "2026-03"  
    
    print(f"--- Running dlt Ingestion for month: {TEST_MONTH or 'ALL'} ---")
    load_info = pipeline.run(green_taxi_resource(selected_month=TEST_MONTH))
    print("dlt Load Summary:")
    print(load_info)
