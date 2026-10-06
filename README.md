# 🚀 Project: Real-Time Airport Operations Analytics Pipeline

A comprehensive, end-to-end data engineering project that simulates, ingests, processes, and visualizes real-time flight operations data using a modern, serverless AWS stack.

### The Problem
Modern airports are complex ecosystems with data generated from dozens of disconnected systems: flight operations, baggage handling, security checkpoints, and ground crew services. This data is often siloed, inconsistent, and not available in real-time, making it difficult for managers to answer critical questions quickly:
* Which airlines are experiencing the most significant delays?
* How does passenger volume correlate with turnaround times?
* What is the live operational status of all active flights?

Answering these questions often requires manual, slow analysis, which is ineffective in a dynamic airport environment.

### The Solution
This project solves the problem by building a centralized, real-time data platform. It ingests raw, messy data, transforms it into a clean, analytics-ready format, and models it in a data warehouse. The end result is a single source of truth that powers a live BI dashboard in AWS QuickSight, providing management with immediate, high-level insights for data-driven decisions.

### High-Level Implementation
The pipeline is built on a serverless AWS stack and follows the **Medallion Architecture**:
1.  **Data Generation:** A containerized Python app on **Amazon ECS** simulates real-time, messy flight data.
2.  **Bronze Layer (Raw Ingestion):** Raw JSON is ingested by **Amazon Kinesis Data Streams**. A parallel **Kinesis Firehose** stream archives every raw record to an **S3 Raw Zone**.
3.  **Silver Layer (Clean & Transform):** An **AWS Glue** streaming job reads from Kinesis, cleans and transforms the data, and loads it into an **S3 Cleaned Zone** (as Parquet) and a **Redshift Staging Table**
4.  **Visualization:** **AWS QuickSight** connects to the Gold Layer in Redshift via a secure, private VPC connection to provide interactive dashboards.

---
## ✨ Key Features
* **End-to-End Pipeline:** Complete data lifecycle from generation to a BI dashboard.
* **Real-Time Ingestion:** Uses Amazon Kinesis for low-latency data streaming.
* **Automated Infrastructure:** All AWS resources are deployed and managed via Terraform (Infrastructure as Code).
* **Advanced Data Modeling:** Implements a robust ELT process with a staging layer and a final Redshift Star Schema.
* **Medallion Architecture:** The data lake is structured into Bronze, Silver, and Gold layers.

## 🏛️ Architecture Diagram
This diagram, created with Eraser.io, outlines the complete architecture of the pipeline.

![AirportOps Architecture Diagram](Images/Airport-Ops-Data-Architecture-Diagram.png)

## 💻 Technology Stack

| Category | Technology | Purpose |
| :--- | :--- | :--- |
| **Infrastructure as Code** | Terraform | Automate provisioning of all AWS resources. |
| **Data Generation** | Python, Docker, Amazon ECS | Simulate a real-time, messy data source. |
| **Real-Time Ingestion** | Amazon Kinesis Data Streams & Firehose | Ingest and archive streaming data at scale. |
| **Storage / Data Lake** | Amazon S3 | Store raw (Bronze) and cleaned (Silver) data. |
| **ETL/ELT** | AWS Glue (Visual ETL) | Clean, transform, and model streaming data. |
| **Data Warehouse** | Amazon Redshift Serverless | Store the final, analytics-ready data (Gold). |
| **BI & Visualization** | AWS QuickSight | Create interactive dashboards and reports. |

---

## ⚙️ Workflow Breakdown
The data flows through the system in the following sequence:
1.  **Data Generation:** An **Amazon ECS Task** is initiated via a Terraform variable change (`desired_tasks = 1`), running a Python script to generate synthetic flight data.
2.  **Real-Time Ingestion:** The script sends each event as a JSON record to an **Amazon Kinesis Data Stream**.
3.  **Parallel Processing (Fan-Out):** The Kinesis stream has two consumers reading in parallel:
    * **Archival Path:** A **Kinesis Firehose** stream archives the raw JSON records into the **S3 Raw Zone (Bronze Layer)** every 60 seconds.
    * **Transformation Path:** An **AWS Glue Streaming Job** reads data from the stream in 60-second windows.
4.  **Transformation & Loading:** The Glue job performs all cleaning and modeling logic. Upon completion, it writes the cleaned data to two targets:
    * The **S3 Cleaned Zone (Silver Layer)** as optimized Parquet files.
    * The **Redshift Staging Table**.
5.  **Final Modeling:** A scheduled SQL query runs inside Redshift to populate the final **Fact and Dimension tables (Gold Layer)** from the staging table.
6.  **Visualization:** **AWS QuickSight** connects to the Redshift Gold Layer tables via a secure VPC connection for analysis.

## 📈 Business Value
This project demonstrates a solution that provides significant business value by:
* **Creating a Single Source of Truth:** Centralizes disparate operational data into a single data warehouse, breaking down data silos.
* **Enabling Real-Time Decision Making:** Shifts from slow, reactive reporting to proactive, near real-time monitoring of KPIs.
* **Improving Operational Efficiency:** Allows managers to instantly identify trends and bottlenecks, such as which airlines have the highest delays.
* **Being Scalable & Cost-Effective:** Utilizes a serverless architecture that scales automatically and minimizes operational overhead.

## 🛠️ Troubleshooting Notes
Common issues and their resolutions:
* **ECS Task Fails:** Usually an IAM permission issue. Ensure the `ECSTaskRole` has `kinesis:PutRecord*` permissions.
* **No Data in S3/Redshift:**
    * **Check Raw Zone First:** If no files are here, the issue is between the ECS container and Kinesis. Check ECS task logs.
    * **Check Cleaned Zone Next:** If the Raw Zone has data but the Cleaned Zone does not, the issue is with the Glue job.
* **Glue Job Fails:**
    * **`Session failure... all ingress ports` error:** The Glue Connection's Security Group needs a self-referencing rule allowing all traffic from itself.
    * **`Connect timed out` to STS/Secrets Manager:** The VPC is missing a VPC Endpoint for that service.
* **QuickSight Connection Fails:**
    * **`Unable to resolve host`:** Redshift is not publicly accessible (for public connections).
    * **`No available instances` (Private Connection):** The QuickSight service needs permissions. Go to "Manage QuickSight" -> "Security & permissions" and enable access to Amazon Redshift.

## 📂 Project Structure & Details
This repository is divided into two main components, each with its own detailed documentation:

* **[📄 Data Simulator README](./Data-Simulator/README.md):** Details on the Python application that generates the synthetic flight data.
* **[📄 Infrastructure (Terraform) README](./Infrastructure/README.md):** Details on the Terraform code used to provision all AWS resources.

## 🚀 How to Deploy
1.  **Prerequisites:** AWS Account, Terraform CLI, AWS CLI configured.
2.  **Clone the repository:** `git clone ...`
3.  **Navigate to the `Infrastructure` directory.**
4.  **Initialize Terraform:** `terraform init`
5.  **Deploy:** `terraform apply` (You will need to provide values for `unique_suffix` and `alert_email` in a `terraform.tfvars` file).

## 📊 Final Dashboard
Here is a screenshot of the final AWS QuickSight dashboard built on top of the Redshift star schema.

![QuickSight Dashboard Screenshot](Images/Airport-Ops-Dashboard.png)
