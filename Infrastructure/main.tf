# main.tf

################################################################################
# DATA SOURCES
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

################################################################################
# NETWORKING
################################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-VPC"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${var.project_name}-PrivateSubnet-A"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "${var.project_name}-PrivateSubnet-B"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-PrivateRouteTable"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# --- THIS SECURITY GROUP IS UPDATED ---
resource "aws_security_group" "main" {
  name        = "${var.project_name}-sg"
  description = "Main security group for the project"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- THIS IS THE RULE THAT FIXES THE ERROR ---
  # Allows Glue workers to communicate with each other on all ports
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # "-1" means all protocols
    self        = true
    description = "Allow all internal traffic for Glue worker communication"
  }

  # Allows services within the security group to communicate with each other over HTTPS (for endpoints)
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    self      = true
  }

  # Allows services within the security group to communicate with Redshift
  ingress {
    from_port = 5439 # Redshift Port
    to_port   = 5439
    protocol  = "tcp"
    self      = true
  }

  tags = {
    Name = "${var.project_name}-SG"
  }
}

################################################################################
# STORAGE (S3)
################################################################################

resource "aws_s3_bucket" "raw_zone" {
  bucket = "airport-raw-zone-${var.unique_suffix}"
  tags = {
    Name = "${var.project_name}-RawZone"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_zone_encryption" {
  bucket = aws_s3_bucket.raw_zone.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "cleaned_zone" {
  bucket = "airport-cleaned-zone-${var.unique_suffix}"
  tags = {
    Name = "${var.project_name}-CleanedZone"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cleaned_zone_encryption" {
  bucket = aws_s3_bucket.cleaned_zone.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

################################################################################
# INGESTION (ECR & KINESIS)
################################################################################

resource "aws_ecr_repository" "simulator" {
  name = "${lower(var.project_name)}-simulator"
  tags = {
    Name = "${var.project_name}-SimulatorRepo"
  }
}

resource "aws_ecr_repository" "glue_env" {
  name = "${lower(var.project_name)}-glue-env"
  tags = {
    Name = "${var.project_name}-GlueEnvRepo"
  }
}

resource "aws_kinesis_stream" "data_stream" {
  name        = "${lower(var.project_name)}-data-stream"
  shard_count = 1
  tags = {
    Name = "${var.project_name}-DataStream"
  }
}

resource "aws_kinesis_firehose_delivery_stream" "archive_stream" {
  name        = "${lower(var.project_name)}-archive-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.data_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.raw_zone.arn
    buffering_interval = 60
    buffering_size     = 5
  }

  tags = {
    Name = "${var.project_name}-ArchiveStream"
  }
}

################################################################################
# ETL & WAREHOUSING (GLUE & REDSHIFT)
################################################################################

resource "aws_glue_catalog_database" "main" {
  name = "${lower(var.project_name)}_db"
}

resource "aws_glue_job" "streaming_etl" {
  name     = "${var.project_name}-StreamingETL"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "gluestreaming"
    script_location = "s3://${aws_s3_bucket.cleaned_zone.bucket}/scripts/glue_etl_script.py"
    python_version  = "3"
  }

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 5
  
  connections = [aws_glue_connection.redshift_connection.name]

  default_arguments = {
    "--worker-type"  = "G.1X",
    "--custom-image" = "${aws_ecr_repository.glue_env.repository_url}:latest"
  }
}

resource "aws_redshiftserverless_namespace" "main" {
  namespace_name      = "${lower(var.project_name)}-namespace"
  admin_username      = "admin"
  admin_user_password = random_password.db_password.result
  iam_roles           = [aws_iam_role.redshift_role.arn]
  db_name             = "dev"
}

resource "aws_redshiftserverless_workgroup" "main" {
  namespace_name = aws_redshiftserverless_namespace.main.namespace_name
  workgroup_name = "${lower(var.project_name)}-workgroup"
  base_capacity  = 8

  # We are keeping Redshift private for security
  publicly_accessible = false

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]
  security_group_ids = [aws_security_group.main.id]
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

################################################################################
# COST MANAGEMENT
################################################################################

resource "aws_budgets_budget" "monthly_project_cost" {
  name         = "${var.project_name}-MonthlyBudget"
  budget_type  = "COST"
  limit_amount = "10.0"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

output "redshift_admin_password" {
  description = "The randomly generated password for the Redshift admin user."
  value       = random_password.db_password.result
  sensitive   = true
}

