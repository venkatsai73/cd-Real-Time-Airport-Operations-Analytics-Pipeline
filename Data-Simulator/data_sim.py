import json
import random
import time
import uuid
import datetime
from datetime import timezone
import boto3
import os
from dotenv import load_dotenv


# --- Configuration ---
load_dotenv()
STREAM_NAME = os.getenv("AWS_KINESIS_STREAM_NAME")
AWS_REGION = os.getenv("AWS_REGION")
HUB_AIRPORT = "AMD"
MAX_ACTIVE_FLIGHTS = 25
SIMULATOR_SLEEP_TIME = float(os.getenv("SIMULATOR_SLEEP_TIME", "1.0"))
# Time Compression: 1 real second = 10 simulated minutes
TIME_STEP = datetime.timedelta(minutes=10)

# --- Sample Data ---
SPOKE_AIRPORTS = ["BOM", "DEL", "BLR", "MAA", "CCU", "HYD", "DXB", "SIN", "LHR", "DOH", "AUH", "KUL"]
AIRLINES = ["6E", "AI", "UK", "SG", "EK", "QR"]
AIRCRAFT_TYPES = ["B777", "A380", "B737", "A320", "B787"]
WEATHER_CONDITIONS = ["Clear", "Hazy", "Rain", "Windy", "Fog"]

class Flight:
    """Represents a single, stateful flight with a complete journey."""

    def __init__(self, current_time):
        # --- Static flight details ---
        self.airline = random.choice(AIRLINES)
        self.flight_icao = f"{self.airline}{random.randint(100, 9999)}"
        self.tail_number = f"VT-{random.choice(['A','B','C'])}{random.choice(['A','B','C'])}{random.choice(['A','B','C'])}"
        self.aircraft_type = random.choice(AIRCRAFT_TYPES)

        if random.random() < 0.5:
            self.departure_airport = HUB_AIRPORT
            self.arrival_airport = random.choice(SPOKE_AIRPORTS)
        else:
            self.departure_airport = random.choice(SPOKE_AIRPORTS)
            self.arrival_airport = HUB_AIRPORT

        # --- Timing Logic based on Time Compression ---
        # A flight's total journey will be compressed into a few minutes of real time.
        flight_duration = datetime.timedelta(minutes=random.randint(30, 90)) # Compressed duration

        journey_progress = random.random()

        self.scheduled_departure = current_time - (flight_duration * journey_progress)
        self.scheduled_arrival = self.scheduled_departure + flight_duration

        self.actual_departure = self.scheduled_departure
        if random.random() < 0.3:
            self.actual_departure += datetime.timedelta(minutes=random.randint(10, 60))

        self.actual_arrival = self.scheduled_arrival
        if random.random() < 0.25:
             self.actual_arrival += datetime.timedelta(minutes=random.randint(-120, 300))

        # --- Dynamic State ---
        self.flight_status = random.choices(["scheduled", "departing", "en-route", "landed"],
                                            weights=[0.3, 0.25, 0.35, 0.1],  # probabilities sum to 1
                                            k=1
                                            )[0]
        self.current_lat = 23.0733
        self.current_lon = 72.6342
        self.altitude_ft = 0
        self.speed_kts = 0
        self.update(current_time) # Set initial state correctly

    def get_messy_timestamp(self, dt_obj):
        formats = [lambda dt: dt.isoformat(), lambda dt: int(dt.timestamp()), lambda dt: dt.strftime("%d/%b/%Y %H:%M:%S")]
        return random.choice(formats)(dt_obj)

    def mess_up_string(self, s):
        if random.random() < 0.2:
            return f"  {random.choice([s.upper(), s.lower(), s.title()])}  "
        return s

    def update_telemetry(self):
        """Helper function to set telemetry based on the current flight status."""
        if self.flight_status == "en-route":
            self.altitude_ft = random.randint(28000, 42000)
            self.speed_kts = random.randint(450, 550)
            self.current_lat += random.uniform(-0.5, 0.5)
            self.current_lon += random.uniform(-0.5, 0.5)
        elif self.flight_status == "departing":
            self.altitude_ft = random.randint(1000, 10000)
            self.speed_kts = random.randint(100, 200)
        else: # Scheduled or Landed
            self.altitude_ft, self.speed_kts = 0, 0

    def update(self, current_time):
        """Updates the flight's state and returns the latest event record."""
        # State Transition Logic
        if self.flight_status == "scheduled" and current_time >= self.actual_departure:
            self.flight_status = "departing"
        elif self.flight_status == "departing" and current_time >= (self.actual_departure + datetime.timedelta(minutes=20)): # Compressed taxi time
            self.flight_status = "en-route"
        elif self.flight_status == "en-route" and current_time >= self.actual_arrival:
            self.flight_status = "landed"

        self.update_telemetry()

        turnaround_time_minutes = None
        if self.flight_status == "landed" and self.arrival_airport == HUB_AIRPORT:
            turnaround_time_minutes = random.randint(45, 120)

        operational_data = {
            "taxi_time_minutes": random.randint(5, 25) if self.flight_status in ["departing", "landed"] else 0,
            "turnaround_time_minutes": turnaround_time_minutes,
            "runway_in_use": f"{random.randint(1, 36)}{random.choice(['L', 'R', 'C'])}",
            "passenger_count": random.randint(80, 450),
            "baggage_count": random.randint(100, 500),
            "security_wait_time_minutes": random.randint(5, 60),
            "aircraft_type": self.aircraft_type,
            "weather_conditions": random.choice(WEATHER_CONDITIONS)
        }

        flight_data = {
            "event_id": str(uuid.uuid4()),
            "event_timestamp": self.get_messy_timestamp(current_time),
            "source_system_id": "simulator-v8.0-time-compressed",
            "flight_details": { "flight_icao": self.flight_icao, "airline_iata": self.airline, "tail_number": self.tail_number },
            "route_info": {
                "departure_airport_iata": self.departure_airport, "arrival_airport_iata": self.arrival_airport,
                "departure_gate": f"{random.choice(['A', 'B', 'C'])}{random.randint(1, 20)}",
                "arrival_gate": f"{random.choice(['A', 'B', 'C'])}{random.randint(1, 20)}",
                "scheduled_departure_utc": self.scheduled_departure.isoformat(),
                "scheduled_arrival_utc": self.scheduled_arrival.isoformat(),
                "actual_departure_utc": self.actual_departure.isoformat(),
                "actual_arrival_utc": self.actual_arrival.isoformat() if self.flight_status == "landed" else None
            },
            "operational_data": operational_data,
            "live_telemetry": {
                "location_str": f"{self.current_lat:.6f};{self.current_lon:.6f}",
                "altitude_ft": self.altitude_ft, "ground_speed_kts": self.speed_kts,
                "vertical_speed_fps": random.randint(-50, 50) if random.random() > 0.1 else None,
                "heading": random.randint(0, 360) if random.random() > 0.1 else None,
                "flight_status": self.mess_up_string(self.flight_status),
            }
        }
        return flight_data

def send_to_kinesis(data_record, kinesis_client):
    try:
        response = kinesis_client.put_record(
            StreamName=STREAM_NAME,
            Data=json.dumps(data_record, default=str).encode('utf-8'),
            PartitionKey=data_record["flight_details"]["flight_icao"]
        )
        return True
    except Exception as e:
        print(f"Error sending record to Kinesis: {e}")
        return False

if __name__ == "__main__":
    print(f"Starting stateful data simulator for hub '{HUB_AIRPORT}'...")
    print(f"Time Compression: 1 real second = {TIME_STEP.total_seconds() / 60} simulated minutes")

    try:
        kinesis_client = boto3.client('kinesis', region_name=AWS_REGION)
        kinesis_client.list_streams()
        print("AWS Kinesis connection successful.")
        SEND_DATA_TO_KINESIS = True
    except Exception as e:
        print(f"Warning: Could not connect to AWS Kinesis. Will run in local print-only mode. Error: {e}")
        kinesis_client = None
        SEND_DATA_TO_KINESIS = False
        exit(1)  # Exit if Kinesis connection fails

    active_flights = {}
    simulation_clock = datetime.datetime.now(timezone.utc)

    while True:
        # Advance the simulation clock
        simulation_clock += TIME_STEP

        landed_flights = [icao for icao, flight in active_flights.items() if flight.flight_status == "landed"]
        for icao in landed_flights:
            del active_flights[icao]
            print(f"Flight {icao} has landed and is removed from simulation.")

        l = []
        while len(active_flights) < MAX_ACTIVE_FLIGHTS:
            new_flight = Flight(simulation_clock)
            active_flights[new_flight.flight_icao] = new_flight
            print(f"New flight created: {new_flight.flight_icao} (Initial Status: {new_flight.flight_status}) from {new_flight.departure_airport} to {new_flight.arrival_airport}")

        for flight in active_flights.values():
            event_data = flight.update(simulation_clock)
            l.append(event_data)
            if SEND_DATA_TO_KINESIS:
                if not send_to_kinesis(event_data, kinesis_client):
                    print("Halting due to Kinesis send error.")
                    break
            else:
                print(f"Generated update for flight: {event_data['flight_details']['flight_icao']} | Status: {event_data['live_telemetry']['flight_status']}")

        print(f"--- Simulation Clock: {simulation_clock.isoformat()} ---")
        time.sleep(SIMULATOR_SLEEP_TIME)
