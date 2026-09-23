# NYC Mobility Gold Data Model

## Overview

The Gold layer uses a **star schema** to separate measurable taxi trip
events from descriptive contextual attributes.

The model consists of **one fact table and three dimension tables**.

``` text
                         dim_datetime
                              │
                              │
                              ▼
                       fact_taxi_trip
                       /           \
                      ▼             ▼
             dim_location     dim_weather
```

## Fact Table

### `fact_taxi_trip`

**Grain:** One row per taxi trip.

  Measure                   Description
  ------------------------- --------------------------
  `passenger_count`         Number of passengers
  `trip_distance`           Trip distance
  `trip_duration_minutes`   Trip duration in minutes
  `fare_amount`             Taxi fare amount
  `total_amount`            Total trip amount

## Dimension Tables

### `dim_datetime`

**Grain:** One row per datetime.

Contains date and time attributes for taxi trip events and is shared by
both pickup and dropoff timestamps.

The datetime design supports analysis by:

-   Time of day
-   Day of week
-   Month
-   Season
-   Weekend
-   Rush-hour periods

Example:

``` text
2026-03-15 08:00 → Morning
2026-03-15 12:00 → Afternoon
2026-03-15 18:00 → Evening
```

### `dim_location`

**Grain:** One row per taxi zone.

Provides NYC taxi zone and location information for geographic analysis.

### `dim_weather`

**Grain:** One row per weather datetime.

Provides weather conditions and measurements for analyzing taxi demand
and trip behavior under different weather conditions.

## Relationships

``` text
                  dim_datetime
                       │
                       ▼
                fact_taxi_trip
                  /          \
                 ▼            ▼
        dim_location      dim_weather
```

The fact table connects taxi trip activity to datetime, location, and
weather context.

## Modeling Principles

-   The fact table maintains a clear taxi-trip grain.
-   Dimensions provide descriptive context for fact records.
-   Surrogate keys are used to map facts to dimensions.
-   A shared `dim_datetime` is used for both pickup and dropoff
    timestamps.
-   The model is designed for analytical querying and dashboard
    reporting.
