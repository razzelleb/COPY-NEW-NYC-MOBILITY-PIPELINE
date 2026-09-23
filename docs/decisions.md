# NYC Mobility Architecture and Data Modeling Decisions

## Overview

The project uses several design decisions to separate ingestion,
transformation, modeling, and analytics while maintaining a consistent
analytical structure.

## 1. Medallion Architecture

The pipeline is separated into Source Inspection, Bronze, Silver, Gold,
and Analytics layers.

This separates source validation, raw ingestion, data cleaning and
transformation, analytical modeling, and business analysis.

## 2. Delta Tables

Delta tables are used for the processing layers to provide reliable
table storage and support safe reruns and incremental processing without
unnecessarily duplicating data.

## 3. Bronze Preserves Raw Data

The Bronze layer preserves the source structure rather than applying
extensive business transformations at ingestion.

Ingestion metadata is added to identify when data entered the pipeline.

## 4. Silver Handles Data Quality

Data cleaning and standardization are primarily handled in the Silver
layer.

This includes:

-   Data type standardization
-   Category standardization
-   Missing-value handling
-   Invalid-value handling
-   Business-rule validation
-   Deduplication

## 5. Gold Uses a Star Schema

The Gold layer uses a fact-and-dimension model consisting of:

-   `fact_taxi_trip`
-   `dim_datetime`
-   `dim_location`
-   `dim_weather`

The fact table represents taxi trip events, while dimensions provide
descriptive context.

## 6. Surrogate Keys

Surrogate keys are used in the Gold dimensional model to map fact
records to their dimensions.

The fact table maintains a defined taxi-trip grain to support consistent
aggregations.

## 7. Shared Datetime Dimension

A shared `dim_datetime` is used for both pickup and dropoff timestamps.

This allows taxi activity to be analyzed consistently by:

-   Hour
-   Day of week
-   Month
-   Season
-   Weekend
-   Rush hour

Separate date and time dimensions are not used.

## 8. Weather Context

Weather data is connected to taxi activity through datetime context.

This allows the project to compare taxi demand and trip characteristics
with weather conditions.

## 9. Data Validation

Validation is performed throughout the pipeline rather than only at the
end.

Checks cover areas such as:

-   Source availability
-   Schema and column structure
-   Row counts
-   Required fields
-   Data types
-   Numeric ranges
-   Duplicates
-   Dimension keys
-   Relationships
-   Analytical grain
