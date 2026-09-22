import requests
from pathlib import Path

# Official NYC TLC Green Taxi Parquet files
BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/"

# Months to download
MONTHS = ["2026-03"]

# Databricks Volume path for the raw datasets
OUTPUT_DIR = Path("/Volumes/nyc/default/nyc-mobility-volume/green_taxi/")


def download_green_taxi(month):
    # Build the official file URL
    filename = f"green_tripdata_{month}.parquet"
    url = BASE_URL + filename

    # Output path in the Databricks Volume
    output_path = OUTPUT_DIR / filename

    # Create the Volume folder if it doesn't exist
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Downloading Green Taxi {month}...")
    print(f"URL: {url}")
    print(f"Saving to: {output_path}")

    # Download the Parquet file
    response = requests.get(url, timeout=60)

    # Stop if the request failed
    response.raise_for_status()

    # Save the file to the Databricks Volume
    output_path.write_bytes(response.content)

    print(f"Downloaded: {output_path}")
    print(f"File size: {output_path.stat().st_size:,} bytes")
    print()


# Run the downloads
if __name__ == "__main__":
    for month in MONTHS:
        download_green_taxi(month)

    print("All Green Taxi files downloaded successfully!")