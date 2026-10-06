# iam.tf

################################################################################
# IAM ROLE FOR GLUE
################################################################################

resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-GlueRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-GlueRole" }
}

# --- NEW: POLICY TO ALLOW GLUE TO PASS ITS OWN ROLE ---
resource "aws_iam_policy" "glue_pass_role_policy" {
  name        = "${var.project_name}-GluePassRolePolicy"
  description = "Allows the Glue role to pass itself to other AWS services"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "iam:PassRole",
        Resource = aws_iam_role.glue_role.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_pass_role_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_pass_role_policy.arn
}
# --------------------------------------------------------


# --- ATTACH AWS MANAGED POLICIES FOR VPC & REDSHIFT ACCESS ---
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_redshift_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess"
}

# --- YOUR CUSTOM POLICY FOR KINESIS, S3, and SECRETS MANAGER ---
resource "aws_iam_policy" "glue_policy" {
  name        = "${var.project_name}-GluePolicy"
  description = "Custom policy for the Glue job"
  policy      = data.aws_iam_policy_document.glue_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "glue_custom_policy_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_policy.arn
}

data "aws_iam_policy_document" "glue_policy_doc" {
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.raw_zone.arn}/*",
      "${aws_s3_bucket.cleaned_zone.arn}/*"
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:DescribeStream", "kinesis:ListShards"]
    resources = [aws_kinesis_stream.data_stream.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = ["*"]
  }
}


################################################################################
# IAM ROLES FOR ECS TASK (Data Simulator)
################################################################################

# --- ROLE 1: TASK ROLE (For the container's application code) ---
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ECSTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ECSTaskRole" }
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "${var.project_name}-ECSTaskPolicy"
  description = "Policy for the ECS data simulator task to write to Kinesis"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ],
        Resource = aws_kinesis_stream.data_stream.arn
      },
      {
        Effect   = "Allow",
        Action   = "kinesis:ListStreams",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_kinesis_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}


# --- ROLE 2: TASK EXECUTION ROLE (For the ECS Agent) ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ECSTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ECSTaskExecutionRole" }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


################################################################################
# IAM ROLE FOR KINESIS FIREHOSE
################################################################################

resource "aws_iam_role" "firehose_role" {
  name = "${var.project_name}-FirehoseRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "firehose.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-FirehoseRole" }
}

resource "aws_iam_policy" "firehose_policy" {
  name        = "${var.project_name}-FirehosePolicy"
  description = "Policy for the Kinesis Firehose to access Kinesis and S3"
  policy      = data.aws_iam_policy_document.firehose_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "firehose_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

data "aws_iam_policy_document" "firehose_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.raw_zone.arn,
      "${aws_s3_bucket.raw_zone.arn}/*",
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["kinesis:DescribeStream", "kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:ListShards"]
    resources = [aws_kinesis_stream.data_stream.arn]
  }
}

################################################################################
# IAM ROLE FOR REDSHIFT
################################################################################

resource "aws_iam_role" "redshift_role" {
  name = "${var.project_name}-RedshiftRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "redshift.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-RedshiftRole" }
}

resource "aws_iam_policy" "redshift_s3_policy" {
  name        = "${var.project_name}-RedshiftS3Policy"
  description = "Allows Redshift to read from the cleaned data S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.cleaned_zone.arn,
          "${aws_s3_bucket.cleaned_zone.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "redshift_s3_read" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = aws_iam_policy.redshift_s3_policy.arn
}


################################################################################
# IAM ROLE FOR QUICKSIGHT VPC CONNECTION
################################################################################

resource "aws_iam_role" "quicksight_vpc_role" {
  name = "${var.project_name}-QuickSightVPCRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "quicksight.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-QuickSightVPCRole"
  }
}



################################################################################
# IAM ROLE FOR QUICKSIGHT VPC + REDSHIFTCONNECTION
################################################################################


# Custom IAM Policy for QuickSight VPC + Redshift connection
resource "aws_iam_policy" "quicksight_vpc_policy" {
  name        = "QuickSightVPCPolicy"
  description = "Custom policy for QuickSight VPC and Redshift connections"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 networking for VPC connection
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeAvailabilityZones",
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = "*"
      },

      # Redshift cluster discovery + access
      {
        Effect = "Allow"
        Action = [
          "redshift:DescribeClusters",
          "redshift:DescribeLoggingStatus",
          "redshift:GetClusterCredentials"
        ]
        Resource = "*"
      },

      # Allow QuickSight to pass the role when connecting
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "${aws_iam_role.quicksight_vpc_role.arn}"
      }
    ]
  })
}

# --- THIS IS THE FIX ---
# Attaches the QuickSight VPC policy to the QuickSight role
resource "aws_iam_role_policy_attachment" "quicksight_vpc_policy_attach" {
  role       = aws_iam_role.quicksight_vpc_role.name
  policy_arn = aws_iam_policy.quicksight_vpc_policy.arn
}