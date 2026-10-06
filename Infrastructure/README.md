# 🏗️ Infrastructure as Code (Terraform)

This directory contains the complete Terraform configuration used to define, provision, and manage all the AWS resources for the Real-Time Airport Operations Analytics Pipeline. The entire infrastructure is automated and follows modern Infrastructure as Code (IaC) best practices.

## Overview

The infrastructure is designed to be secure, scalable, and modular. It creates a private network environment (VPC) where all services communicate securely, with minimal exposure to the public internet. The configuration is broken down into logical files to ensure clarity and maintainability.

---

## 📂 File Structure & Purpose

The Terraform configuration is organized into the following files, each with a specific responsibility:

| File Name | Purpose |
| :--- | :--- |
| **`main.tf`** | 📜 **Core Orchestrator:** Defines primary resources like the VPC, Subnets, S3 buckets, Kinesis streams, and Redshift cluster. |
| **`iam.tf`** | 🔐 **Security & Permissions:** Contains all IAM Roles and Policies for each service (Glue, ECS, Redshift, etc.). |
| **`ecs.tf`** | 🐳 **Data Generation:** Defines the AWS ECS Cluster and Task Definition for the data simulator container. |
| **`vpc_endpoint.tf`**| 🌐 **Private Networking:** Creates all necessary VPC Endpoints for secure communication between services inside the VPC and AWS APIs. |
| **`glue_connection.tf`**| 🔗 **ETL Connectivity:** Defines the secure JDBC connection for the AWS Glue job to connect to the Redshift database. |
| **`quicksight.tf`** | 📊 **BI Connectivity:** Defines resources for a secure, private VPC connection between AWS QuickSight and Redshift. |
| **`secrets.tf`** | 🤫 **Secrets Management:** Defines resources for securely storing and managing credentials, like the Redshift password. |
| **`variables.tf`** | 🔧 **Configuration:** Defines input variables (e.g., region, project name) for customization. |
| **`versions.tf`** | ⚙️ **Provider Management:** Specifies required versions for Terraform and AWS providers for stable deployments. |
| **`terraform.tfvars`**| 🔑 **Deployment Values:** Your local file (not in Git) where you provide specific, secret values for variables. |

---

## ✨ Key Resources Managed

This Terraform setup provisions a complete, production-ready environment:

* **Secure Networking:** A private VPC with multiple subnets, security groups, and a full suite of VPC Endpoints to ensure services like Glue, ECS, and Redshift can communicate without exposing them to the public internet.
* **Containerized Compute:** An ECS Cluster and Fargate Task Definition to run the Python data simulator in a serverless, scalable manner. The data generation can be toggled on and off by changing a single variable.
* **Real-Time Ingestion:** An Amazon Kinesis Data Stream for low-latency ingestion and an attached Kinesis Firehose for automatically archiving raw data to S3.
* **Serverless ETL:** An AWS Glue Streaming Job and a dedicated Glue Data Connection for privately connecting to Redshift.
* **Serverless Data Warehouse:** An Amazon Redshift Serverless Namespace and Workgroup, providing a powerful, auto-scaling analytical database.
* **Secure BI:** A private VPC connection for AWS QuickSight, ensuring that data analysis also happens over a secure, private network.

---

## 🚀 How to Deploy

Follow these steps to deploy the entire infrastructure using the Terraform CLI.

1.  **Create a Variables File:**
    Make a copy of the example variables file.
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```
    Now, edit `terraform.tfvars` and provide your own unique values for `unique_suffix` and `alert_email`.

2.  **Initialize Terraform:**
    This command downloads the necessary provider plugins.
    ```bash
    terraform init
    ```

3.  **Review the Plan:**
    This command shows you all the resources that Terraform will create, change, or destroy. It's a crucial step to review before making any changes.
    ```bash
    terraform plan
    ```

4.  **Apply the Configuration:**
    This command will build and provision all the resources in your AWS account.
    ```bash
    terraform apply
    ```

## 🔑 Key Outputs

After a successful deployment, Terraform will provide key pieces of information.

* **`redshift_admin_password`**: This is the randomly generated password for your Redshift database's admin user. You can retrieve it at any time by running:
    ```bash
    terraform output redshift_admin_password
    ```
* **`redshift_workgroup_endpoint`**: This is the JDBC endpoint for your Redshift Serverless workgroup, which you will need to connect from QuickSight or a SQL client. Retrieve it with:
    ```bash
    terraform output redshift_workgroup_endpoint
    ```