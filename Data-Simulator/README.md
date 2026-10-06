# 🐍 Data Simulator

This directory contains the Python application responsible for generating synthetic, real-time flight data for the Airport Operations Analytics Pipeline.

## 🎯 Purpose
The simulator is designed to mimic a real-world, complex data source. It produces a continuous stream of nested JSON records with several **intentional irregularities**. This creates a realistic and challenging dataset that requires a robust ELT pipeline to clean, transform, and model the data correctly.

---

## ✨ Key Features & Data Irregularities
The script is engineered to generate "messy" data to thoroughly test the pipeline's data cleaning and transformation capabilities.

| Irregularity Type | Field(s) Affected | Description |
| :--- | :--- | :--- |
| **Inconsistent Timestamps** | `event_timestamp` | The timestamp is deliberately randomized into one of three different formats: an ISO 8601 string, a Unix integer, or a custom string (e.g., `24/Sep/2025...`). |
| **Messy Strings** | `live_telemetry.flight_status` | The flight status string is randomly altered with different casings (`UPPER`, `lower`, `Title`) and padded with extraneous whitespace. |
| **Null Values** | `actual_arrival_utc`, `heading`, etc. | Key fields are set to `null` under certain conditions (e.g., a flight has not yet landed) to simulate incomplete data records. |
| **Combined Data** | `live_telemetry.location_str` | Latitude and longitude are combined into a single, semicolon-separated string (e.g., `"19.0886;72.8679"`) that must be parsed. |

---

## 📄 Sample JSON Output
Here is an example of a single JSON record produced by the simulator. Note the nested structure and some of the messy data features like the custom `event_timestamp` format and `null` telemetry values.

> This complex, nested structure is a direct input into the Kinesis Data Stream.

```json
{
  "event_id": "a1b2c3d4-e5f6-4a5b-8c9d-012345abcdef",
  "event_timestamp": "24/Sep/2025 18:15:30",
  "source_system_id": "simulator-v8.0-time-compressed",
  "flight_details": {
    "flight_icao": "6E1234",
    "airline_iata": "6E",
    "tail_number": "VT-ABC"
  },
  "route_info": {
    "departure_airport_iata": "BOM",
    "arrival_airport_iata": "AMD",
    "departure_gate": "A12",
    "arrival_gate": "C8",
    "scheduled_departure_utc": "2025-09-24T18:00:00",
    "scheduled_arrival_utc": "2025-09-24T19:00:00",
    "actual_departure_utc": "2025-09-24T18:05:00",
    "actual_arrival_utc": null
  },
  "operational_data": {
    "taxi_time_minutes": 15,
    "turnaround_time_minutes": null,
    "runway_in_use": "27R",
    "passenger_count": 180,
    "baggage_count": 210,
    "security_wait_time_minutes": 25,
    "aircraft_type": "A320",
    "weather_conditions": "Clear"
  },
  "live_telemetry": {
    "location_str": "19.0886;72.8679",
    "altitude_ft": 35000,
    "ground_speed_kts": 455,
    "vertical_speed_fps": null,
    "heading": null,
    "flight_status": " en-route "
  }
}
```

---

## 🚀 Running the Simulator
You can run the simulator in two ways: inside a Docker container for a clean, isolated environment, or directly in a local Python environment for development.

### Option 1: With Docker (Recommended)
1.  **Build the Docker image:**
    ```bash
    docker build -t airport-simulator .
    ```
2.  **Run the container:**
    ```bash
    docker run --rm -e AWS_REGION="your-region" -e AWS_KINESIS_STREAM_NAME="your-stream-name" airport-simulator
    ```

### Option 2: Local Python Environment
1.  **Create a virtual environment:**
    ```bash
    python -m venv venv
    ```
2.  **Activate the virtual environment:**
    * On Windows:
        ```bash
        .\venv\Scripts\activate
        ```
    * On macOS/Linux:
        ```bash
        source venv/bin/activate
        ```
3.  **Install Python Dependencies:**
    This project's dependencies are listed in the `requirements.txt` file. Install them using pip:
    ```bash
    pip install -r requirements.txt
    ```
4.  **Configure Environment Variables:**
    Create a file named `.env` in this directory and add your AWS credentials and configuration:
    ```
    AWS_REGION=your-region
    AWS_KINESIS_STREAM_NAME=your-stream-name
    SIMULATOR_SLEEP_TIME=1.0
    AWS_ACCESS_KEY_ID=your_access_key
    AWS_SECRET_ACCESS_KEY=your_secret_key
    ```
5.  **Run the script:**
    ```bash
    python data_sim.py
    ```