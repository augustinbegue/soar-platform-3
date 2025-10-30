# ========================================
# Stockage des credentials dans Secrets Manager
# ========================================

resource "aws_secretsmanager_secret" "aurora_credentials" {
  # Append a stable random suffix to avoid name conflicts with secrets scheduled for deletion
  name        = "${var.name_prefix}-aurora-credentials-${random_id.suffix.hex}"
  description = "Credentials for Aurora PostgreSQL cluster ${var.name_prefix}"
  tags        = local.tags
}

resource "aws_secretsmanager_secret_version" "aurora_credentials_version" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = var.master_password
  })
}
# ========================================
# Security group rule: autoriser ECS sur 5432
# ========================================

resource "aws_security_group_rule" "aurora_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = length(var.security_group_ids) > 0 ? var.security_group_ids[0] : aws_security_group.aurora[0].id
  source_security_group_id = var.ecs_security_group_id
  description              = "Allow PostgreSQL from ECS tasks"
  depends_on               = [aws_rds_cluster.aurora]
}
# ========================================
# Aurora Writer Instance (Serverless v2)
# ========================================

resource "aws_rds_cluster_instance" "writer" {
  identifier           = "${var.name_prefix}-aurora-writer"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = "db.serverless" # Aurora Serverless v2
  engine               = var.engine
  engine_version       = var.engine_version != "" ? var.engine_version : null
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.aurora.name
  tags                 = local.tags
}
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${var.name_prefix}-aurora-cluster"
  engine                  = var.engine
  engine_version          = var.engine_version != "" ? var.engine_version : null
  engine_mode             = var.engine_mode # "provisioned" pour serverless v2
  # Database name must start with a letter and contain only alphanumeric characters.
  # Sanitize var.name_prefix to remove non-alphanumeric characters (e.g. hyphens).
  # Remove common separators (hyphens) from the name_prefix so DB name is alphanumeric.
  database_name           = "${replace(var.name_prefix, "-", "")}_db"
  master_username         = var.master_username
  master_password         = var.master_password
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = length(var.security_group_ids) > 0 ? var.security_group_ids : [aws_security_group.aurora[0].id]
  backup_retention_period = var.backup_retention_period
  # Control whether a final snapshot is created on deletion. Default true = skip snapshot (useful for dev).
  skip_final_snapshot     = var.skip_final_snapshot
  # If skip_final_snapshot is false, provide a final snapshot identifier. Use provided value or generate one.
  final_snapshot_identifier = var.skip_final_snapshot ? null : (var.final_snapshot_identifier != "" ? var.final_snapshot_identifier : "${var.name_prefix}-final-${random_id.suffix.hex}")
  storage_encrypted       = true
  deletion_protection     = false
  apply_immediately       = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }

  tags = local.tags
}

# Fallback security group for Aurora when none provided by caller
resource "aws_security_group" "aurora" {
  count       = length(var.security_group_ids) == 0 ? 1 : 0
  name        = "${var.name_prefix}-aurora-sg"
  description = "Security group for Aurora cluster (created when no SG provided)"
  vpc_id      = var.vpc_id

  # By default, deny ingress; explicit ingress rules are managed separately
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
locals {
  tags = {
    Component = "aurora"
    Name      = var.name_prefix
  }
}

# Stable random suffix for resource names (avoids collisions with scheduled-for-deletion secrets)
resource "random_id" "suffix" {
  byte_length = 4
}

# TODO: Provision the Aurora cluster and related infrastructure, including:
#   - aws_db_subnet_group spanning the provided database_subnet_ids
#   - aws_rds_cluster with multi-AZ writer and reader instances
#   - aws_rds_cluster_instance resources distributed across all AZs
#   - aws_rds_cluster_parameter_group for engine tuning
#   - Monitoring, performance insights, and automated backups
# Integrate credentials via Secrets Manager or SSM where possible.


# ========================================
# Aurora DB Subnet Group
# ========================================

resource "aws_db_subnet_group" "aurora" {
  name        = "${var.name_prefix}-aurora-subnet-group"
  subnet_ids  = var.database_subnet_ids
  description = "Aurora DB subnet group for ${var.name_prefix}"
  tags        = local.tags
}
