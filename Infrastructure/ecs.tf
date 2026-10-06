# ecs.tf

################################################################################
# ECS - Container Orchestration for the Data Simulator
################################################################################

# 1. The ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-Cluster"
  tags = {
    Name = "${var.project_name}-Cluster"
  }
}

# 2. The ECS Task Definition
resource "aws_ecs_task_definition" "simulator" {
  family                   = "${var.project_name}-SimulatorTask"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  # --- CORRECTED: Use the two separate roles defined in iam.tf ---
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "data-simulator"
      image     = aws_ecr_repository.simulator.repository_url
      essential = true
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "AWS_KINESIS_STREAM_NAME"
          value = aws_kinesis_stream.data_stream.name
        },
        {
          name  = "SIMULATOR_SLEEP_TIME"
          value = "1.0" # Default for normal operation
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.simulator.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-SimulatorTask"
  }
}

# 3. The ECS Service
resource "aws_ecs_service" "simulator" {
  name            = "${var.project_name}-SimulatorService"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.simulator.arn
  launch_type     = "FARGATE"

  # --- CHANGED: Use the variable from variables.tf to control the service ---
  desired_count = var.desired_tasks

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.main.id]
  }

  tags = {
    Name = "${var.project_name}-SimulatorService"
  }
}

# 4. CloudWatch Log Group
resource "aws_cloudwatch_log_group" "simulator" {
  name = "/ecs/${var.project_name}-simulator"
  tags = {
    Name = "${var.project_name}-SimulatorLogs"
  }
}