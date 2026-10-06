# ==============================================================================
# AWS Glue Streaming ETL Job for Airport Operations Analytics
#
# Description:
# This script defines a real-time ETL job that reads a stream of nested,
# messy flight data from an Amazon Kinesis Data Stream. It performs a series
# of transformations to clean, enrich, and model the data into a final
# star schema, which is then loaded into Amazon Redshift and backed up to
# Amazon S3.
# ==============================================================================

import sys
from awsglue.transforms import * # type: ignore
from awsglue.utils import getResolvedOptions # type: ignore
from pyspark.context import SparkContext # type: ignore
from awsglue.context import GlueContext # type: ignore
from awsglue.job import Job # type: ignore
from pyspark.sql import functions as F # type: ignore
from awsglue.dynamicframe import DynamicFrame, DynamicFrameCollection # type: ignore
import datetime

# ==============================================================================
# Transformation Logic
# ==============================================================================

def transform_flight_data(glueContext, initial_df):
    """
    Applies all cleaning, enrichment, and modeling transformations to the raw
    flight data DataFrame.

    :param glueContext: The AWS Glue context.
    :param initial_df: The initial Spark DataFrame from the Kinesis micro-batch.
    :return: A dictionary of Spark DataFrames for each target table (staging, dims, fact).
    """
    
    # --- 1. Unnest and Clean Initial Data (Silver Layer) ---
    # Unnest the nested JSON fields and create a flat table structure.
    # A '_' delimiter is used to create Redshift-compatible column names.
    unnested_df = initial_df.select(
        "flight_details.flight_icao",
        "flight_details.airline_iata",
        "flight_details.tail_number",
        "route_info.departure_airport_iata",
        "route_info.arrival_airport_iata",
        "route_info.departure_gate",
        "route_info.arrival_gate",
        "route_info.scheduled_departure_utc",
        "route_info.scheduled_arrival_utc",
        "route_info.actual_departure_utc",
        "route_info.actual_arrival_utc",
        "operational_data.taxi_time_minutes",
        "operational_data.turnaround_time_minutes",
        "operational_data.runway_in_use",
        "operational_data.passenger_count",
        "operational_data.baggage_count",
        "operational_data.security_wait_time_minutes",
        "operational_data.aircraft_type",
        "operational_data.weather_conditions",
        "live_telemetry.location_str",
        "live_telemetry.altitude_ft",
        "live_telemetry.ground_speed_kts",
        "live_telemetry.vertical_speed_fps",
        "live_telemetry.heading",
        F.lower(F.trim(F.col("live_telemetry.flight_status"))).alias("live_telemetry_flight_status")
    )
    
    # Split the combined location string into separate latitude and longitude columns.
    split_loc = F.split(unnested_df.live_telemetry_location_str, ";")
    location_df = unnested_df.withColumn("live_telemetry_latitude", split_loc.getItem(0)) \
                               .withColumn("live_telemetry_longitude", split_loc.getItem(1)) \
                               .drop("live_telemetry_location_str")

    # --- 2. Calculate Delay Metrics ---
    # Calculate departure delay
    actual_dep_ts = F.unix_timestamp(location_df.route_info_actual_departure_utc, "yyyy-MM-dd'T'HH:mm:ss")
    scheduled_dep_ts = F.unix_timestamp(location_df.route_info_scheduled_departure_utc, "yyyy-MM-dd'T'HH:mm:ss")
    delay_df = location_df.withColumn("departure_delay_seconds_total", actual_dep_ts - scheduled_dep_ts)
    delay_df = delay_df.withColumn("departure_delay_hours", (F.col("departure_delay_seconds_total") / 3600).cast("int"))
    delay_df = delay_df.withColumn("departure_delay_minutes", ((F.col("departure_delay_seconds_total") % 3600) / 60).cast("int"))
    delay_df = delay_df.withColumn("departure_delay_seconds", (F.col("departure_delay_seconds_total") % 60).cast("int"))
    
    # Calculate arrival delay, handling nulls for flights that have not yet landed.
    actual_arr_ts = F.unix_timestamp(delay_df.route_info_actual_arrival_utc, "yyyy-MM-dd'T'HH:mm:ss")
    scheduled_arr_ts = F.unix_timestamp(delay_df.route_info_scheduled_arrival_utc, "yyyy-MM-dd'T'HH:mm:ss")
    delay_df = delay_df.withColumn("arrival_delay_seconds_total",
        F.when(
            F.col("route_info_actual_arrival_utc").isNotNull(),
            actual_arr_ts - scheduled_arr_ts
        ).otherwise(None)
    )
    delay_df = delay_df.withColumn("arrival_delay_hours", (F.col("arrival_delay_seconds_total") / 3600).cast("int"))
    delay_df = delay_df.withColumn("arrival_delay_minutes", ((F.col("arrival_delay_seconds_total") % 3600) / 60).cast("int"))
    delay_df = delay_df.withColumn("arrival_delay_seconds", (F.col("arrival_delay_seconds_total") % 60).cast("int"))

    # Fill any null delay values with 0.
    delay_columns = ["departure_delay_hours", "departure_delay_minutes", "departure_delay_seconds", "arrival_delay_hours", "arrival_delay_minutes", "arrival_delay_seconds"]
    staging_df = delay_df.fillna(0, subset=delay_columns).drop("departure_delay_seconds_total", "arrival_delay_seconds_total")
    
    # --- 3. Create Dimension and Fact DataFrames (Gold Layer) ---
    
    # Create the DataFrame for the dim_flights table
    dim_flights_df = staging_df.select(
        F.col("flight_details_flight_icao").alias("flight_icao"),
        F.col("flight_details_airline_iata").alias("airline_iata"),
        F.col("flight_details_tail_number").alias("tail_number"),
        F.col("operational_data_aircraft_type").alias("aircraft_type")
    ).distinct()
    
    # Create the DataFrame for the fact_flight_activity table
    fact_flight_activity_df = staging_df.select(
        "flight_details_flight_icao", # Business key for joining
        "route_info_departure_airport_iata", # Business key for joining
        "route_info_arrival_airport_iata", # Business key for joining
        F.col("operational_data_passenger_count").alias("passenger_count"),
        F.col("operational_data_baggage_count").alias("baggage_count"),
        "departure_delay_minutes",
        "arrival_delay_minutes"
    )
    
    return {
        "staging_table": staging_df,
        "dim_flights": dim_flights_df,
        "fact_flight_activity": fact_flight_activity_df
    }

# ==============================================================================
# Main Execution Logic
# ==============================================================================

# --- 1. Initialization ---
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'TempDir'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# --- 2. Read from Kinesis Source ---
# Create a streaming DataFrame from the Kinesis Data Stream.
# 'windowSize' defines the batch interval.
kinesis_df = glueContext.create_data_frame.from_options(
    connection_type="kinesis",
    connection_options={
        "typeOfData": "kinesis", 
        "streamARN": "<STREAM_ARN>", 
        "classification": "json", 
        "startingPosition": "latest", 
        "inferSchema": "true"
    }
)

# --- 3. Process Each Batch ---
def processBatch(data_frame, batchId):
    """
    This function is executed for each micro-batch of data from the Kinesis stream.
    """
    if (data_frame.count() > 0):
        # --- 3.1. Apply all transformations ---
        transformed_dataframes = transform_flight_data(glueContext, data_frame)
        
        # --- 3.2. Convert Spark DataFrames back to Glue DynamicFrames for writing ---
        staging_dyf = DynamicFrame.fromDF(transformed_dataframes["staging_table"], glueContext, "staging_dyf")
        dim_flights_dyf = DynamicFrame.fromDF(transformed_dataframes["dim_flights"], glueContext, "dim_flights_dyf")
        fact_flight_activity_dyf = DynamicFrame.fromDF(transformed_dataframes["fact_flight_activity"], glueContext, "fact_flight_activity_dyf")

        # --- 3.3. Write to Sinks ---
        # Define paths and options for the S3 sinks
        now = datetime.datetime.now()
        s3_base_path = "<S3_PATH>"
        partition_path = f"ingest_year={now.year}/ingest_month={now.month:0>2}/ingest_day={now.day:0>2}/ingest_hour={now.hour:0>2}/"
        
        # Write the staging table to S3 (Silver Layer)
        glueContext.write_dynamic_frame.from_options(
            frame=staging_dyf,
            connection_type="s3",
            format="glueparquet",
            connection_options={"path": s3_base_path + "flight_events_staging/" + partition_path},
            format_options={"compression": "snappy"}
        )

        # Write the dimension table to S3 (Gold Layer backup)
        glueContext.write_dynamic_frame.from_options(
            frame=dim_flights_dyf,
            connection_type="s3",
            format="glueparquet",
            connection_options={"path": s3_base_path + "dim_flights/" + partition_path},
            format_options={"compression": "snappy"}
        )

        # Write the fact table to S3 (Gold Layer backup)
        glueContext.write_dynamic_frame.from_options(
            frame=fact_flight_activity_dyf,
            connection_type="s3",
            format="glueparquet",
            connection_options={"path": s3_base_path + "fact_flight_activity/" + partition_path},
            format_options={"compression": "snappy"}
        )
        
        # Write the staging table to Redshift
        glueContext.write_dynamic_frame.from_options(
            frame=staging_dyf, 
            connection_type="redshift", 
            connection_options={
                "redshiftTmpDir": "<TEMP_DIR_PATH>", 
                "useConnectionProperties": "true", 
                "dbtable": "public.flight_events_staging", 
                "connectionName": "AirportOps-redshift-database-connection"
            }
        )
        
# --- 4. Start the Streaming Job ---
# The forEachBatch function triggers the processing for each micro-batch.
glueContext.forEachBatch(
    frame=kinesis_df,
    batch_function=processBatch,
    options={
        "windowSize": "60 seconds",
        "checkpointLocation": args["TempDir"] + "/" + args["JOB_NAME"] + "/checkpoint/"
    }
)

# --- 5. Commit the Job ---
job.commit()