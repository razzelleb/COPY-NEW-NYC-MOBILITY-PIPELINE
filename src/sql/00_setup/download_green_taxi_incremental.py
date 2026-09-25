import argparse
import re
from pathlib import Path
import requests

BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/"
OUTPUT_DIR = Path("/Volumes/nyc/default/nyc-mobility-volume/green_taxi/")
DEFAULT_START_MONTH = "2026-03"  # Starting point if volume is empty


def get_next_month_to_ingest(default_start: str = DEFAULT_START_MONTH) -> str:
    """Scans OUTPUT_DIR for existing green_tripdata_YYYY-MM.parquet files,
    finds the latest month present, and returns the NEXT month YYYY-MM.

    If no files exist yet, returns default_start ('2026-03').
    """
    if not OUTPUT_DIR.exists():
        return default_start

    # Scan for existing parquet files
    existing_files = list(OUTPUT_DIR.glob("green_tripdata_*.parquet"))

    months = []
    for file_path in existing_files:
        # Safely extract YYYY-MM from filename (e.g. green_tripdata_2026-05.parquet -> 2026-05)
        match = re.search(r"green_tripdata_(\d{4}-\d{2})", file_path.name)
        if match:
            months.append(match.group(1))

    # If volume is empty or no files match, start from default_start
    if not months:
        return default_start

    # Find the latest month in the volume (e.g., '2026-05')
    latest_month_str = max(months)

    # Calculate the next month
    year, month = map(int, latest_month_str.split("-"))
    next_month = month % 12 + 1
    next_year = year + (1 if next_month == 1 else 0)

    return f"{next_year:04d}-{next_month:02d}"


def download_green_taxi(month: str, force: bool = False) -> bool:
    """Downloads a single month of Green Taxi data idempotently and safely."""
    filename = f"green_tripdata_{month}.parquet"
    url = BASE_URL + filename
    output_path = OUTPUT_DIR / filename

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Idempotency Check: Skip if file already exists in Volume
    if output_path.exists() and not force:
        print(f"[SKIP] {filename} already exists at {output_path}.")
        return True

    print(f"Targeting next missing month: {month}...")

    # 2. Safe Download with HTTP Error Protection
    try:
        response = requests.get(url, timeout=60)
        response.raise_for_status()
        output_path.write_bytes(response.content)
        print(
            f"[SUCCESS] Downloaded: {output_path} ({output_path.stat().st_size:,} bytes)\n"
        )
        return True

    except requests.exceptions.HTTPError as e:
        # Gracefully handle unreleased months on NYC TLC server
        if response.status_code in (403, 404):
            print(
                f"[NOT AVAILABLE] {filename} is not published yet on NYC TLC servers (HTTP {response.status_code}). Skipping safely.\n"
            )
        else:
            print(f"[ERROR] Failed to download {filename}: {e}\n")
        return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Download NYC Green Taxi Parquet file for the next missing month."
    )

    # Automatically set target to the month AFTER the newest file in the Volume
    next_target_month = get_next_month_to_ingest(
        default_start=DEFAULT_START_MONTH
    )

    parser.add_argument(
        "--month",
        type=str,
        default=next_target_month,
        help="Target month YYYY-MM (defaults to the month after the latest file in Volume).",
    )
    parser.add_argument(
        "--force", action="store_true", help="Force re-download."
    )
    args = parser.parse_args()

    download_green_taxi(args.month, force=args.force)