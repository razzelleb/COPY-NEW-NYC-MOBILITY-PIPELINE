import argparse
from pathlib import Path
import requests

# ==========================================
# CONFIGURATION — EDIT TARGET MONTH HERE (1 LINE)
# ==========================================
TARGET_MONTH = "2026-03"  # Change this line to set default month

BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/"
OUTPUT_DIR = Path("/Volumes/nyc/default/nyc-mobility-volume/green_taxi/")


def download_green_taxi(month: str, force: bool = False):
    """Downloads a single month of Green Taxi data idempotently."""
    filename = f"green_tripdata_{month}.parquet"
    url = BASE_URL + filename
    output_path = OUTPUT_DIR / filename

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Skip download if file already exists in Volume
    if output_path.exists() and not force:
        print(f"[SKIP] {filename} already exists at {output_path}.")
        return

    print(f"Downloading Green Taxi data for {month}...")
    print(f"URL: {url}")
    print(f"Saving to: {output_path}")

    response = requests.get(url, timeout=60)
    response.raise_for_status()

    output_path.write_bytes(response.content)
    print(
        f"[SUCCESS] Downloaded: {output_path} ({output_path.stat().st_size:,} bytes)\n"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Download NYC Green Taxi Parquet file."
    )
    parser.add_argument(
        "--month",
        type=str,
        default=TARGET_MONTH,
        help="Target month YYYY-MM (defaults to top-level TARGET_MONTH variable).",
    )
    parser.add_argument(
        "--force", action="store_true", help="Force re-download."
    )

    args = parser.parse_args()
    download_green_taxi(args.month, force=args.force)