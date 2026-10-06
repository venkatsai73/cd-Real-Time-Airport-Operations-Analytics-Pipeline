# vpc_endpoints.tf

################################################################################
# VPC ENDPOINTS
################################################################################

# Endpoint for ECR API (Authentication)
# Allows the ECS task to get authorization tokens to pull images.
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-ECR-API-Endpoint" }
}

# Endpoint for ECR DKR (Pulling Images)
# Allows the ECS task to pull the actual container image layers.
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-ECR-DKR-Endpoint" }
}

# S3 Gateway Endpoint (Required by ECR and for Glue)
# ECR stores its image layers in S3, and Glue needs to access scripts.
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.private.id]
  tags            = { Name = "${var.project_name}-S3-Gateway-Endpoint" }
}

# Endpoint for CloudWatch Logs
# Allows the ECS task and Glue job to send logs to CloudWatch.
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-Logs-Endpoint" }
}

# Endpoint for Kinesis Data Streams
# Allows the ECS task to send data to your Kinesis stream.
resource "aws_vpc_endpoint" "kinesis_streams" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.kinesis-streams"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-Kinesis-Endpoint" }
}

# Endpoint for Redshift Data API
# Allows the Glue job to connect to the Redshift cluster to load data.
resource "aws_vpc_endpoint" "redshift_data" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.redshift-data"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-Redshift-Data-Endpoint" }
}

# --- NEW: Endpoint for STS (Security Token Service) ---
# Allows services within the VPC like Glue to assume IAM roles.
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-STS-Endpoint" }
}

# Endpoint for AWS Secrets Manager
# Allows the Glue job to retrieve credentials for the Redshift connection.
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.main.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-SecretsManager-Endpoint" }
}


