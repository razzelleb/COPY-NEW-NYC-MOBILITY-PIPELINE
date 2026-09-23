# NYC Taxi Zones Dataset Schema

## 1. Dataset Overview
### Dataset Name

NYC Taxi Zone Lookup Table

### Source
New York City Taxi and Limousine Commission (NYC TLC)

### Official Source Page
https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

### Direct CSV Source
https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv

### File Format

CSV

### Dataset Type

Reference / lookup dataset

The Taxi Zone Lookup Table maps a numeric `LocationID` to a
geographic taxi zone, borough, and service zone category.

This is a reference dataset rather than a trip-level transactional
dataset. It does not contain pickup or drop-off timestamps, fares,
trip distances, or other trip-level measures.

---

## 2. Local Collection

### Local File

```text
data/raw/taxi_zone_lookup.csv
```

**Collection Method**


The CSV was downloaded from the official NYC TLC source using Python and the requests library.

The download script is:
scripts/taxi_zones/download_taxi_zones.py

The dataset was then loaded locally using pandas for inspection and data-quality validation.

Inspection script:
scripts/taxi_zones/inspect_taxi_zones.py

Quality-check script:
scripts/taxi_zones/quality_check_taxi_zones.py

## 3. Dataset Size

The downloaded Taxi Zone Lookup Table contains:
Metric	Result
Rows	265
Columns	4

## 4. Columns and Data Types

The dataset contains the following columns:

Column	Data Type	Description	Role
LocationID	integer	Identifier for the Taxi Zone	Key
Borough	string	Borough or geographic category associated with the zone	Dimension
Zone	string	Name of the Taxi Zone	Dimension
service_zone	string	Taxi service zone/category	Dimension
Column Details
LocationID

Numeric identifier assigned to the Taxi Zone.

All 265 records have unique LocationID values. The values range
from 1 to 265 with no missing or unexpected IDs.

LocationID is therefore the strongest candidate for the
business/primary key of the Taxi Zone lookup table.

Borough

Identifies the borough or geographic category associated with
the Taxi Zone.

Observed values include:

Bronx
Brooklyn
Manhattan
Queens
Staten Island
EWR
Unknown
N/A in the raw source
Zone

Contains the Taxi Zone name.

Zone names are descriptive and are not guaranteed to be unique.
Therefore, Zone should not be used as the primary key.

service_zone

Identifies the service-zone category.

Observed values include:
Boro Zone
Yellow Zone
Airports
EWR
N/A in the raw source

## 5. Data Quality Checks

## 5.1 Duplicate Rows

Result:
Duplicate rows: 0
There are no completely duplicated records.

## 5.2 Duplicate LocationIDs

Result:
Unique LocationIDs: 265
Missing LocationIDs: 0
No duplicate LocationID records were found.

Because there are 265 rows and 265 unique LocationID values,
LocationID is a strong candidate key for this lookup table.

## 5.3 LocationID Range and Sequence

Observed range:
Minimum LocationID: 1
Maximum LocationID: 265
The expected sequence from 1 through 265 was checked.

Result:
Missing IDs: []
Unexpected IDs: []

Therefore, the downloaded dataset contains the complete
LocationID sequence from 1 to 265 with no gaps or unexpected IDs.

## 5.4 Duplicate Zone Names

There are:
265 total rows
261 unique Zone names

Five records were identified as part of repeated zone names:
LocationID 56
LocationID 57

LocationID 103
LocationID 104
LocationID 105

This demonstrates that the Zone column is not unique.

Therefore:
LocationID = key
Zone        = descriptive attribute

## 6. Borough Distribution

The observed borough values are:
Borough	Count
Queens	69
Manhattan	69
Brooklyn	61
Bronx	43
Staten Island	20
EWR	1
Unknown	1
N/A*	1
Total	265

* N/A is the literal value present in the raw CSV for
LocationID 265. When the CSV is read with pandas' default
NA parsing, it is interpreted as NaN.

## 7. Service Zone Distribution

The observed service_zone values are:
Service Zone	Count
Boro Zone	205
Yellow Zone	55
Airports	2
EWR	1
N/A*	2
Total	265

* The raw CSV contains the literal value N/A for
LocationID 264 and LocationID 265.

When loaded using pandas' default NA parsing, these values appear
as NaN.

## 8. Special Records

The final two records contain special geographic values.

LocationID 264

Raw source values:
LocationID	Borough	Zone	service_zone
264	Unknown	N/A	N/A
LocationID 265

Raw source values:
LocationID	Borough	Zone	service_zone
265	N/A	Outside of NYC	N/A

These records should be preserved in the raw dataset.

They should not be deleted during ingestion simply because they
contain N/A values. Any future transformation or business rule
for handling these records should be defined in the appropriate
clean/silver layer.

## 9. Missing-Value Behavior

When the CSV is loaded using pandas' default:
pd.read_csv(FILE_PATH)
pandas interprets values such as NA and N/A as missing values.

This resulted in:
LocationID      0
Borough         1
Zone            1
service_zone    2

However, inspection of the raw source using:

pd.read_csv(
    FILE_PATH,
    keep_default_na=False
)

confirmed that these are literal source values rather than
empty CSV cells.

The raw values are:

LocationID 264:
Borough = Unknown
Zone = N/A
service_zone = N/A

LocationID 265:
Borough = N/A
Zone = Outside of NYC
service_zone = N/A

Therefore, the NaN values observed during normal pandas loading
are a result of pandas' default NA parsing.

## 10. Dimensions vs. Measures

This dataset is a reference/dimension dataset.

Dimensions

The following columns are descriptive dimensions:

LocationID
Borough
Zone
service_zone
Measures

There are no measures in the Taxi Zone Lookup Table.

The dataset does not contain:

trip counts
fares
revenue
distance
duration
passenger counts
timestamps

Measures will come from trip-level datasets such as Green Taxi
trip records and can be aggregated by Taxi Zone using LocationID.

## 11. Relationship to Green Taxi Trip Records

The Taxi Zone Lookup Table is used to interpret location IDs in
NYC TLC trip records.

For Green Taxi records:

green_taxi.PULocationID
        ↓
taxi_zone_lookup.LocationID

and:

green_taxi.DOLocationID
        ↓
taxi_zone_lookup.LocationID
Pickup Location

PULocationID identifies the Taxi Zone in which the taximeter
was engaged.

Drop-off Location

DOLocationID identifies the Taxi Zone in which the taximeter
was disengaged.

Therefore, the Taxi Zone Lookup Table can be joined to Green Taxi
trip data using LocationID.

Conceptually:

                 Taxi Zone Lookup
              ┌─────────────────────┐
              │ LocationID           │
              │ Borough              │
              │ Zone                 │
              │ service_zone         │
              └──────────┬──────────┘
                         │
                    LocationID
                         │
              ┌──────────┴──────────┐
              │                     │
        PULocationID          DOLocationID
              │                     │
              └──────────┬──────────┘
                         │
                  Green Taxi Trips

This relationship allows trip-level pickup and drop-off IDs to be
translated into geographic attributes such as borough, zone name,
and service-zone category.

## 12. Recommended Data Model Role

The Taxi Zone Lookup Table should be treated as a dimension/reference
table in the project's data model.

Recommended conceptual table:

dim_taxi_zone

Suggested structure:

dim_taxi_zone
-------------
LocationID       PK
Borough
Zone
service_zone

LocationID should be used as the key for joining Taxi Zone
information to trip-level datasets.

## 13. Relevance to Business Questions

The Taxi Zone dataset provides geographic context for NYC TLC
trip records.

It can be used to answer questions such as:

Which Taxi Zones have the highest pickup demand?
Which zones have the highest drop-off demand?
How does demand vary by borough?
Which service zones receive the most trips?
How does taxi activity vary by day or hour across zones?
Which areas may represent mobility opportunities?

For example:

Green Taxi trip
       ↓
PULocationID
       ↓
dim_taxi_zone.LocationID
       ↓
Borough / Zone / service_zone
       ↓
Aggregate taxi demand

## 14. Validation Summary

The Taxi Zone CSV was successfully downloaded and validated locally.

Summary:

Rows:                    265
Columns:                   4
Duplicate rows:            0
Unique LocationIDs:      265
Missing LocationIDs:       0
LocationID range:       1–265
Missing IDs:               0
Unexpected IDs:            0
Unique Zone names:       261

The dataset is structurally suitable as a reference/dimension
table for joining NYC TLC trip records through LocationID.

The raw dataset should be preserved without deleting or modifying
the special N/A records. Any standardization of these values
should be handled in the appropriate downstream cleaning layer.

## 15. Coverage / Time Context

The Taxi Zone Lookup dataset is a reference/lookup dataset rather than a time-series trip dataset. It defines Taxi Zone and LocationID information used to interpret pickup and drop-off locations in TLC trip records.

Therefore, the dataset does not have a trip-date or monthly coverage period like the Green Taxi trip records.

Local collection date: September 14, 2026.

## 16. Source Validation

The official Taxi Zone Lookup CSV was downloaded successfully from the NYC Taxi & Limousine Commission source and parsed successfully as a CSV file.

The downloaded file was validated locally and contained:

- 265 rows
- 4 columns
- Expected columns:
  - `LocationID`
  - `Borough`
  - `Zone`
  - `service_zone`

The file was successfully parsed as structured tabular data rather than an error or HTML response.

