# quicksight.tf

# Data source to get the current AWS Account ID for the QuickSight connection
data "aws_caller_identity" "current" {}

# 1. A new Security Group for the QuickSight Network Interface
resource "aws_security_group" "quicksight_sg" {
  name        = "${var.project_name}-quicksight-sg"
  description = "Security group for QuickSight VPC connection"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic from the QuickSight ENI
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-QuickSight-SG"
  }
}

# 2. The QuickSight VPC Connection Resource
resource "aws_quicksight_vpc_connection" "redshift_private_connection" {
  aws_account_id    = data.aws_caller_identity.current.account_id
  vpc_connection_id = "${var.project_name}-redshift-vpc-connection"
  name              = "Redshift Private Connection"

  # Pass the IAM role ARN created in iam.tf
  role_arn = aws_iam_role.quicksight_vpc_role.arn

  # Provide both private subnets for high availability
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [
    aws_security_group.quicksight_sg.id
  ]

  # Ensure IAM policy is attached before creating the connection
  depends_on = [
    aws_iam_role.quicksight_vpc_role,
    aws_iam_policy.quicksight_vpc_policy,
    aws_iam_role_policy_attachment.quicksight_vpc_policy_attach
  ]
}
