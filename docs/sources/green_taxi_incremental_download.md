# NYC Green Taxi - Incremental Raw Data Download Documentation

## 1. Overview
This module handles fetching raw NYC Green Taxi trip dataset files directly from the NYC Taxi & Limousine Commission (TLC) official CloudFront repository and storing them inside a Databricks Unity Catalog Volume.

- **Purpose**: Automates raw data acquisition prior to pipeline execution.
- **Data Source**: NYC TLC CloudFront Public Endpoint (`https://d37ci6vzurychx.cloudfront.net/trip-data/`)
- **Target Storage**: Databricks Unity Catalog Volume (`/Volumes/nyc/default/nyc-mobility-volume/green_taxi/`)
- **Format**: Parquet (`.parquet`)

---

## 2. Technical Dependencies & Modules
- **`requests`**: Handles HTTP `GET` requests to stream file downloads over SSL.
- **`pathlib.Path`**: Ensures cross-platform file path management and automated directory creation.

---

## 3. Script Explanation (`src/sql/00_setup/download_green_taxi_incremental.py`)

```python
import requests
from pathlib import Path

# Base CloudFront CDN endpoint hosting TLC Parquet files
BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/"

# List of target monthly datasets to download
MONTHS = ["2026-03", "2026-04", "2026-05"]

# Unity Catalog Volume target path
OUTPUT_DIR = Path("/Volumes/nyc/default/nyc-mobility-volume/green_taxi/")

def download_green_taxi(month: str) -> None:
    """
    Downloads a single month's Green Taxi Parquet file from NYC TLC CloudFront
    and saves it to the designated Unity Catalog Volume.
    """
    filename = f"green_tripdata_{month}.parquet"
    url = f"{BASE_URL}{filename}"
    output_path = OUTPUT_DIR / filename
    
    # Ensure directory structure exists
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    print(f"Downloading {filename} from {url}...")
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    
    # Save raw file content to Volume
    output_path.write_bytes(response.content)
    print(f"Successfully saved to {output_path}")

if __name__ == "__main__":
    for month in MONTHS:
        download_green_taxi(month)
```

### Detailed Breakdown:
1. **URL Construction**: Concatenates `BASE_URL` with dataset names formatted as `green_tripdata_YYYY-MM.parquet`.
2. **Directory Guard (`mkdir`)**: Guarantees the Unity Catalog Volume folder exists before attempting to write data.
3. **HTTP Streaming & Validation**: `response.raise_for_status()` raises an exception if a file URL returns `404` or `500` status errors.
4. **Binary File Persistence**: Writes raw response bytes directly to disk via `write_bytes()`.

---

## 4. Execution & Verification

### Running the Download Script
Execute via Databricks job task:
```bash
python src/sql/00_setup/download_green_taxi_incremental.py
```
