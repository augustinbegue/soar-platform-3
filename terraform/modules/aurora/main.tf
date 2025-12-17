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

  # Writer instance explicitly in first AZ
  availability_zone = length(var.availability_zones) > 0 ? var.availability_zones[0] : null

  # Performance Insights for monitoring CPU, connections, and database metrics
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  tags = merge(local.tags, {
    Role = "writer"
    AZ   = length(var.availability_zones) > 0 ? var.availability_zones[0] : "auto"
  })
}

# ========================================
# Aurora Read Replicas (Serverless v2)
# One reader per additional AZ (writer already covers first AZ)
# ========================================

# Read replica in AZ-B
resource "aws_rds_cluster_instance" "reader_b" {
  count = length(var.availability_zones) > 1 ? 1 : 0

  identifier           = "${var.name_prefix}-aurora-reader-b"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = "db.serverless"
  engine               = var.engine
  engine_version       = var.engine_version != "" ? var.engine_version : null
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.aurora.name
  availability_zone    = var.availability_zones[1]

  # Performance Insights for monitoring CPU, connections, and database metrics
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  tags = merge(local.tags, {
    Role = "reader"
    AZ   = var.availability_zones[1]
  })
}

# Read replica in AZ-C
resource "aws_rds_cluster_instance" "reader_c" {
  count = length(var.availability_zones) > 2 ? 1 : 0

  identifier           = "${var.name_prefix}-aurora-reader-c"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = "db.serverless"
  engine               = var.engine
  engine_version       = var.engine_version != "" ? var.engine_version : null
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.aurora.name
  availability_zone    = var.availability_zones[2]

  # Performance Insights for monitoring CPU, connections, and database metrics
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  tags = merge(local.tags, {
    Role = "reader"
    AZ   = var.availability_zones[2]
  })
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.name_prefix}-aurora-cluster"
  engine             = var.engine
  engine_version     = var.engine_version != "" ? var.engine_version : null
  engine_mode        = var.engine_mode # "provisioned" pour serverless v2
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
  skip_final_snapshot = var.skip_final_snapshot
  # If skip_final_snapshot is false, provide a final snapshot identifier. Use provided value or generate one.
  final_snapshot_identifier = var.skip_final_snapshot ? null : (var.final_snapshot_identifier != "" ? var.final_snapshot_identifier : "${var.name_prefix}-final-${random_id.suffix.hex}")
  storage_encrypted         = true
  deletion_protection       = false
  apply_immediately         = true

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = var.serverless_min_capacity
    max_capacity = var.serverless_max_capacity
  }

  tags = local.tags
}

# Parameter group to disable SSL requirement
resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${var.name_prefix}-aurora-params"
  family      = "aurora-postgresql17"
  description = "Aurora cluster parameter group for ${var.name_prefix}"

  parameter {
    name         = "rds.force_ssl"
    value        = "0"
    apply_method = "immediate"
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
