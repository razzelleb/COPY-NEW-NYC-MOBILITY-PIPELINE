# NYC Green Taxi - Bronze Idempotent Ingestion Documentation

## 1. Overview & Architecture Goal
This document covers the implementation details for the **Bronze Ingestion Layer** of the NYC Green Taxi mobility pipeline (`src/sql/01_bronze_ingest/ingest_green_taxi_idempotent.py`).

The primary objective of this module is to replace the previous full-table overwrite strategy (`mode("overwrite")`) with a **file-aware incremental append model**. 

- **Target Table**: `nyc.nyc_bronze.green_taxi_bronze`
- **Source Location**: `/Volumes/nyc/default/nyc-mobility-volume/green_taxi/*.parquet`
- **Processing Engine**: PySpark
- **Core Functionality**: Detects newly dropped monthly Parquet files in the Unity Catalog Volume, attaches lineage metadata, and appends only uningested files into Delta Lake Bronze storage.

---

## 2. Requirements Compliance Checklist

| Requirement | Implementation Details | Status |
| :--- | :--- | :--- |
| **Review Current Ingestion** | Refactored `ingest_green_taxi.py` to eliminate full table overwrites. | **Completed** |
| **Incremental File Detection** | Inspects `_metadata.file_name` against distinct `source_file` values stored in `nyc_bronze.green_taxi_bronze`. | **Completed** |
| **Incremental Appending** | Appends only uningested Parquet files to Bronze using `mode("append")`. | **Completed** |
| **Lineage Metadata** | Captures `source_file`, `source_month`, `bronze_ingestion_timestamp`, and `bronze_ingestion_date`. | **Completed** |
| **Safe Re-runs** | Prevents re-reading or re-appending existing Parquet files when the script is rerun. | **Completed** |

---

## 3. PySpark Script (`src/sql/01_bronze_ingest/ingest_green_taxi_idempotent.py`)

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Initialize Spark Session
spark = SparkSession.builder.getOrCreate()

# Storage Path and Catalog Target
SOURCE_DIR = "/Volumes/nyc/default/nyc-mobility-volume/green_taxi/"
BRONZE_TABLE = "nyc.nyc_bronze.green_taxi_bronze"

print(f"Scanning for Green Taxi Parquet files in {SOURCE_DIR}...")

# 1. Read raw Parquet files and capture file lineage metadata
df_raw = (
    spark.read
    .parquet(f"{SOURCE_DIR}*.parquet")
    .select("*", "_metadata.file_name")
)

# 2. Enrich raw DataFrame with mandatory audit and partitioning metadata
df_enriched = (
    df_raw
    .withColumn("source_file", F.col("file_name"))
    .withColumn("source_month", F.date_format(F.col("lpep_pickup_datetime"), "yyyy-MM"))
    .withColumn("bronze_ingestion_timestamp", F.current_timestamp())
    .withColumn("bronze_ingestion_date", F.current_date())
    .drop("file_name")
)

# 3. Incremental File Filtering Logic
if spark.catalog.tableExists(BRONZE_TABLE):
    # Extract list of distinct files already processed into Bronze
    existing_files = [
        row.source_file 
        for row in spark.read.table(BRONZE_TABLE).select("source_file").distinct().collect()
    ]
    
    # Filter DataFrame to include ONLY new/uningested files
    df_to_ingest = df_enriched.filter(~F.col("source_file").isin(existing_files))
    
    new_files_count = df_to_ingest.select("source_file").distinct().count()
    
    if new_files_count > 0:
        print(f"Found {new_files_count} new file(s). Appending to {BRONZE_TABLE}...")
        df_to_ingest.write.format("delta").mode("append").saveAsTable(BRONZE_TABLE)
    else:
        print("No new files found. Bronze table is fully up to date.")
else:
    # Initial execution: Create table and ingest initial dataset
    print(f"Initializing Bronze table {BRONZE_TABLE}...")
    df_enriched.write.format("delta").mode("overwrite").saveAsTable(BRONZE_TABLE)

print("Bronze ingestion process completed successfully.")
```

---

## 4. Detailed Code Explanation

### Step 1: Raw File & Metadata Extraction
- **`spark.read.parquet(...)`**: Scans the Unity Catalog Volume directory for `.parquet` files.
- **`_metadata.file_name`**: Accesses Spark's built-in file metadata column to record the exact filename (e.g., `green_tripdata_2026-03.parquet`) associated with each row.

### Step 2: Lineage Enrichment
- **`source_file`**: Promotes `_metadata.file_name` into a persistent table column for tracking.
- **`source_month`**: Formats `lpep_pickup_datetime` into `YYYY-MM` string format.
- **`bronze_ingestion_timestamp` / `bronze_ingestion_date`**: Records the exact system time and date when the Spark job executed.

### Step 3: Incremental File Filtering & Appending
- **`spark.catalog.tableExists(BRONZE_TABLE)`**: Checks whether the target Bronze Delta table has already been initialized.
- **`existing_files` List**: Collects all distinct `source_file` values recorded in the Bronze Delta transaction log.
- **`~F.col("source_file").isin(existing_files)`**: Performs a set difference (diff) between disk files in the Volume and existing files in the table.
- **`mode("append")`**: Appends only newly discovered files to the table without altering or overwriting existing historical records.
