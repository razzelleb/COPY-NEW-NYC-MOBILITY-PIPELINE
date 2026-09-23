# NYC Mobility Pipeline Architecture

## Overview

The NYC Mobility project follows a **Medallion Architecture** that
progressively transforms source data into an analytical data warehouse.

``` text
Parquet Files ──────┐
                    │
CSV Files ──────────┼──► Source Inspection
                    │          │
Open API ───────────┘          ▼
                            Bronze
                              │
                              ▼
                            Silver
                              │
                              ▼
                             Gold
                              │
                              ▼
                          Analytics
```

The architecture separates source validation, ingestion, transformation,
analytical modeling, and business analysis.

## Source Systems

  Source           Format     Purpose
  ---------------- ---------- -------------------------------------
  NYC Green Taxi   Parquet    Taxi trip activity
  NYC Taxi Zones   CSV        Taxi zone and location information
  Open-Meteo       Open API   Weather conditions and measurements

Source data is inspected before ingestion to establish an understanding
of schema, completeness, and data-quality characteristics.

## Pipeline Layers

### Source Inspection

Validates incoming NYC Mobility data before ingestion.

Key activities:

-   Inspect source schemas
-   Check for missing or empty data
-   Compare monthly Green Taxi schemas
-   Establish a data-quality baseline

### Bronze

Stores raw source data in Delta tables.

Key activities:

-   Preserve source structure
-   Ingest source data
-   Add ingestion metadata
-   Provide a reliable foundation for downstream processing

### Silver

Creates clean and standardized datasets.

Key activities:

-   Standardize data types and categories
-   Handle missing and invalid values
-   Apply business rules
-   Remove duplicates
-   Prepare taxi, location, and weather data for analytical modeling

### Gold

Provides the analytical data warehouse.

The Gold layer contains:

-   `fact_taxi_trip`
-   `dim_datetime`
-   `dim_location`
-   `dim_weather`

See [`data-model.md`](data-model.md) for the detailed Gold design.

### Analytics

Uses Gold data to answer the project's business questions.

Analysis includes taxi demand by time, pickup and dropoff patterns, trip
characteristics, geographic mobility patterns, and weather-related taxi
behavior.

## Processing Flow

``` text
1. Setup
2. Source Inspection
3. Bronze Ingestion
4. Bronze Validation
5. Silver Transformation
6. Silver Validation
7. Gold Modeling
8. Gold Validation
9. Analytics
10. Analytics Validation
```

## Storage

Source files are placed in the configured Databricks Volume:

``` text
<volume>/
├── green_taxi/
├── weather/
└── taxi_zones/
```

The processing layers use Delta tables.

## Technology Stack

-   **Databricks**
-   **Delta Lake**
-   **Unity Catalog**
-   **SQL**
-   **Python**
