# variables.tf

variable "aws_region" {
  description = "The AWS region where all resources will be created."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "A unique name for the project, used for tagging resources."
  type        = string
  default     = "AirportOps"
}

variable "unique_suffix" {
  description = "A unique suffix (e.g., your initials and a number) to ensure resource names like S3 buckets are globally unique."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the main VPC."
  type        = string
  default     = "10.0.0.0/16"
}

# NEW: Specific variables for each subnet
variable "private_subnet_a_cidr" {
  description = "The CIDR block for private subnet A."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_b_cidr" {
  description = "The CIDR block for private subnet B."
  type        = string
  default     = "10.0.2.0/24"
}


variable "alert_email" {
  description = "The email address to send AWS Budget alerts to."
  type        = string
  sensitive   = true
}

# --- NEW: Variable to control the ECS Service ---
# This allows you to start and stop the data generator without changing the code.
variable "desired_tasks" {
  description = "Number of data simulator tasks to run. Set to 1 to start, 0 to stop."
  type        = number
  default     = 0
}