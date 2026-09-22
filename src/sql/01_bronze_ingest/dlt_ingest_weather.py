import os

import dlt
import requests
import pendulum

try:
    dbutils
except NameError:
    pass  # running locally: dlt reads credentials from .dlt/secrets.toml
else:
    # running as a Databricks job task: no .dlt/secrets.toml on the cluster,
    # so populate the env vars dlt's databricks destination reads instead
    os.environ["DESTINATION__DATABRICKS__CREDENTIALS__SERVER_HOSTNAME"] = dbutils.secrets.get(
        scope="dlt-weather", key="server-hostname"
    )
    os.environ["DESTINATION__DATABRICKS__CREDENTIALS__HTTP_PATH"] = dbutils.secrets.get(
        scope="dlt-weather", key="http-path"
    )
    os.environ["DESTINATION__DATABRICKS__CREDENTIALS__ACCESS_TOKEN"] = dbutils.secrets.get(
        scope="dlt-weather", key="access-token"
    )
    os.environ["DESTINATION__DATABRICKS__CREDENTIALS__CATALOG"] = "nyc"

BASE_URL = "https://archive-api.open-meteo.com/v1/archive"

LATITUDE = 40.7128
LONGITUDE = -74.0060
START_DATE = "2026-03-01"
END_DATE = "2026-05-31"

HOURLY_FIELDS = [
    "temperature_2m",
    "precipitation",
    "rain",
    "snowfall",
    "wind_speed_10m",
    "weather_code",
]


@dlt.resource(
    name="weather_hourly",
    write_disposition="merge",   # rerunning this does NOT create duplicates
    primary_key="timestamp",     # this is the natural key dlt merges on
    columns={
        "timestamp": {"data_type": "timestamp"},
        "temperature_2m": {"data_type": "double"},
        "precipitation": {"data_type": "double"},
        "rain": {"data_type": "double"},
        "snowfall": {"data_type": "double"},
        "wind_speed_10m": {"data_type": "double"},
        "weather_code": {"data_type": "bigint"},
    },
)
def open_meteo_weather():
    params = {
        "latitude": LATITUDE,
        "longitude": LONGITUDE,
        "start_date": START_DATE,
        "end_date": END_DATE,
        "hourly": HOURLY_FIELDS,
        "timezone": "America/New_York",
    }

    response = requests.get(BASE_URL, params=params, timeout=60)
    response.raise_for_status()
    hourly = response.json()["hourly"]

    ingested_at = pendulum.now("UTC")

    for i in range(len(hourly["time"])):
        yield {
            "timestamp": hourly["time"][i],
            "temperature_2m": hourly["temperature_2m"][i],
            "precipitation": hourly["precipitation"][i],
            "rain": hourly["rain"][i],
            "snowfall": hourly["snowfall"][i],
            "wind_speed_10m": hourly["wind_speed_10m"][i],
            "weather_code": hourly["weather_code"][i],
            "source_file": "open_meteo_api",
            "bronze_ingestion_timestamp": ingested_at,
            "bronze_ingestion_date": ingested_at.date(),
        }


if __name__ == "__main__":
    pipeline = dlt.pipeline(
        pipeline_name="nyc_mobility_weather",
        destination="databricks",
        dataset_name="nyc_bronze",
    )

    load_info = pipeline.run(open_meteo_weather(), table_name="weather_bronze_dlt")
    print(load_info)