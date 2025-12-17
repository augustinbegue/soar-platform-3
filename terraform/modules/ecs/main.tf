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
  count = var.enable_alb ? 1 : 0

  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "Allow HTTP traffic from ALB"
}

# Allow HTTP from internet (only when no ALB)
resource "aws_security_group_rule" "ecs_from_internet" {
  count = var.enable_alb ? 0 : 1

  type              = "ingress"
  from_port         = 3001
  to_port           = 3001
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow backend traffic from internet (no ALB mode)"
}

# Allow ECS tasks to connect to Aurora on PostgreSQL port
resource "aws_security_group_rule" "aurora_from_ecs" {
  count = length(var.aurora_security_group_ids) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = var.aurora_security_group_ids[0]
  description              = "Allow PostgreSQL traffic from ECS tasks"
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

# Additional policy for accessing Secrets Manager
resource "aws_iam_role_policy" "ecs_task_execution_secrets_policy" {
  name = "${var.name_prefix}-ecs-task-execution-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.db_secret_arn
      }
    ]
  })
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

# Policy to allow ECS Exec (for debugging and metadata access)
resource "aws_iam_role_policy" "ecs_task_role_exec_policy" {
  name = "${var.name_prefix}-ecs-task-exec-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:DescribeTaskDefinition",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
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

locals {
  # Build dynamic reader endpoint environment variables from AZ-keyed map
  reader_env_vars = [
    for az, endpoint in var.db_reader_endpoints_per_az : {
      name  = "DB_READER_${upper(substr(az, length(az) - 1, 1))}"
      value = endpoint
    }
  ]

  # Static environment variables
  static_env_vars = [
    { name = "PORT", value = "3001" },
    { name = "HOST", value = "0.0.0.0" },
    { name = "ENVIRONMENT", value = "dev" },
    { name = "DB_WRITER_HOST", value = var.db_writer_endpoint },
    { name = "DB_READER_FALLBACK", value = var.db_reader_endpoint },
    { name = "DB_PORT", value = "5432" },
    { name = "DB_NAME", value = var.db_name },
    { name = "DATABASE_USE_CLUSTER", value = "false" },
    { name = "NODE_TLS_REJECT_UNAUTHORIZED", value = "0" }
  ]

  # Combined environment variables
  container_env_vars = concat(local.static_env_vars, local.reader_env_vars)
}

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
      name      = "app"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = 3001
          protocol      = "tcp"
        }
      ]

      entryPoint = ["/bin/sh", "-c"]
      command = [
        "TASK_AZ=$(wget -qO- $ECS_CONTAINER_METADATA_URI_V4/task 2>/dev/null | grep -o 'AvailabilityZone\":\"[^\"]*' | cut -d'\"' -f3) && echo \"Detected AZ: $TASK_AZ\" && if echo \"$TASK_AZ\" | grep -q 'a$'; then DB_READ_HOST=\"$DB_READER_A\"; echo \"Using AZ-A reader\"; elif echo \"$TASK_AZ\" | grep -q 'b$'; then DB_READ_HOST=\"$DB_READER_B\"; echo \"Using AZ-B reader\"; elif echo \"$TASK_AZ\" | grep -q 'c$'; then DB_READ_HOST=\"$DB_READER_C\"; echo \"Using AZ-C reader\"; else DB_READ_HOST=\"$DB_READER_FALLBACK\"; echo \"Using fallback reader\"; fi && export DATABASE_URL_WRITER=\"postgresql://$DB_USER:$DB_PASSWORD@$DB_WRITER_HOST:$DB_PORT/$DB_NAME\" && export DATABASE_URL_READER=\"postgresql://$DB_USER:$DB_PASSWORD@$DB_READ_HOST:$DB_PORT/$DB_NAME\" && export DATABASE_URL=\"$DATABASE_URL_WRITER\" && echo \"Writer: $DB_WRITER_HOST\" && echo \"Reader: $DB_READ_HOST\" && exec node index.js"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "app"
        }
      }

      environment = local.container_env_vars

      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${var.db_secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.db_secret_arn}:password::"
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
    assign_public_ip = !var.enable_alb
  }

  dynamic "load_balancer" {
    for_each = length(var.target_group_arns) > 0 ? [1] : []
    content {
      target_group_arn = var.target_group_arns[0]
      container_name   = "app"
      container_port   = 3001
    }
  }

  # Enable ECS Exec for debugging (optional but useful)
  enable_execute_command = true

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-app-service"
  })
}

# ========================================
# ECS Auto-Scaling Configuration
# ========================================

# Auto-scaling target for ECS service
resource "aws_appautoscaling_target" "ecs_service" {
  count = var.autoscaling_enabled ? 1 : 0

  max_capacity       = 9
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.app]
}

# Target tracking scaling policy based on ALB request count per target
resource "aws_appautoscaling_policy" "ecs_request_count_scaling" {
  count = var.autoscaling_enabled && var.enable_alb ? 1 : 0

  name               = "${var.name_prefix}-request-count-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 1200
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
    disable_scale_in   = false

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_arn_suffix
    }
  }
}

# CloudWatch Alarm for high CPU (scale-out trigger)
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  count = var.autoscaling_enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 30
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "ECS service CPU utilization is above 30% for 30 seconds"
  alarm_actions       = []

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(local.tags, {
    Name      = "${var.name_prefix}-ecs-cpu-high-alarm"
    Threshold = "30"
  })
}

# CloudWatch Alarm for low CPU (scale-in trigger)
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_low" {
  count = var.autoscaling_enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-ecs-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 20
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "ECS service CPU utilization is below 20% for 20 seconds"
  alarm_actions       = []

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(local.tags, {
    Name      = "${var.name_prefix}-ecs-cpu-low-alarm"
    Threshold = "20"
  })
}

