# ⚙️ AWS Glue ETL Job

This directory contains the assets for the real-time streaming ETL job, including the final PySpark script and a diagram of the visual workflow.

## Overview
This job is the core of the data transformation process. It is a streaming job built with **AWS Glue Visual ETL** that reads raw, nested JSON data from a Kinesis Data Stream, performs a series of complex transformations, and loads the cleaned and modeled data into Amazon Redshift and Amazon S3.

The job follows the principles of the **Medallion Architecture**, taking raw Bronze-layer data and producing clean Silver-layer (staging) and modeled Gold-layer (analytics) datasets.

---

## 🏛️ ETL Job Diagram
This diagram shows the complete visual workflow of the AWS Glue job as designed in Glue Studio.

![Airport Ops ETL Diagram](../Images/Airport-Ops-ETL-Diagram.png)


### Transformation Logic Breakdown
The job performs the following key transformations in sequence:
1.  **Source (Kinesis):** Ingests streaming data in 60-second micro-batches.
2.  **Unnest & Clean:** Uses a "Data Preparation Recipe" node to unnest the complex JSON structure into a flat table, using an underscore (`_`) as a delimiter to create valid column names. It also splits the combined location string into separate latitude and longitude columns.
3.  **Polish Flight Status:** A "SQL" transform node trims whitespace and converts the `live_telemetry_flight_status` field to lowercase for consistency.
4.  **Calculate Delays:** A "Custom Transform" node with a PySpark script calculates the `departure_delay` and `arrival_delay` metrics in hours, minutes, and seconds. It correctly handles null values for flights that have not yet landed.
5.  **Schema Enforcement:** An `ApplyMapping` transform is used to ensure the final data types of the columns match the target Redshift table schema.
6.  **Load to Sinks:** The final, cleaned DataFrame is written in parallel to two destinations:
    * **Amazon S3 (Silver Layer):** The full, cleaned staging data is written to the `airport-cleaned-zone` S3 bucket in Parquet format.
    * **Amazon Redshift (Gold Layer):** The data is loaded directly into the final `fact` and `dimension` tables in the Redshift data warehouse.

---

## 📜 ETL Script
The visual workflow above was converted into the following production-ready PySpark script. This script is deployed and executed by the AWS Glue job.

You can find the full script here: **[etl_job.py](./etl_script.py)**