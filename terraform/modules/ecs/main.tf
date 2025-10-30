locals {
  tags = {
    Component = "ecs"
    Name      = var.name_prefix
  }
}

# TODO: Define the ECS control plane and capacity, for example:
#   - aws_ecs_cluster with container insights enabled
#   - aws_autoscaling_group or Fargate capacity providers spanning capacity_subnet_ids
#   - aws_ecs_service definitions linking to ALB target groups
#   - AWS Service Discovery or Route53 records for service discovery
# Ensure services are distributed across all private_subnet_ids for HA.

# ========================================
# ECS Cluster
# ========================================

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-cluster"
  })
}

# ========================================
# Fargate Capacity Provider
# ========================================

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ========================================
# Security Group for ECS Tasks
# ========================================

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name_prefix}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-ecs-tasks-sg"
  })
}

# Allow traffic from ALB to ECS (only if ALB is configured)
resource "aws_security_group_rule" "ecs_from_alb" {
  count = var.alb_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "Allow HTTP traffic from ALB"
}

# Allow HTTP from internet (only when no ALB)
resource "aws_security_group_rule" "ecs_from_internet" {
  count = var.alb_security_group_id == "" ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow HTTP traffic from internet (no ALB mode)"
}

# ========================================
# IAM Role for ECS Task Execution
# ========================================

# This role is used by ECS to:
# - Pull container images from ECR
# - Push logs to CloudWatch
# - Retrieve secrets from Secrets Manager

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-ecs-task-execution-role"
  })
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ========================================
# IAM Role for ECS Task (Application)
# ========================================

# This role is used BY YOUR APPLICATION to:
# - Access S3 buckets
# - Write to DynamoDB
# - Call other AWS services

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-ecs-task-role"
  })
}

# Policy to allow logging to CloudWatch (for application logs)
resource "aws_iam_role_policy" "ecs_task_role_cloudwatch_policy" {
  name = "${var.name_prefix}-ecs-task-cloudwatch-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ========================================
# CloudWatch Log Group
# ========================================

resource "aws_cloudwatch_log_group" "ecs_tasks" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-ecs-logs"
  })
}

# ========================================
# ECS Task Definition
# ========================================

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 0.5 GB

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "nginx"
        }
      }

      environment = [
        {
          name  = "ENVIRONMENT"
          value = "dev"
        }
      ]
    }
  ])

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-app-task"
  })
}

# ========================================
# Data Sources
# ========================================

data "aws_region" "current" {}

# ========================================
# ECS Service
# ========================================

resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.cluster_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = length(var.target_group_arns) == 0 ? true : false
  }

  dynamic "load_balancer" {
    for_each = length(var.target_group_arns) > 0 ? [1] : []
    content {
      target_group_arn = var.target_group_arns[0]
      container_name   = "nginx"
      container_port   = 80
    }
  }

  # Enable ECS Exec for debugging (optional but useful)
  enable_execute_command = true

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-app-service"
  })
}
