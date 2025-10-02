locals {
  tags = {
    Component = "aurora"
    Name      = var.name_prefix
  }
}

# TODO: Provision the Aurora cluster and related infrastructure, including:
#   - aws_db_subnet_group spanning the provided database_subnet_ids
#   - aws_rds_cluster with multi-AZ writer and reader instances
#   - aws_rds_cluster_instance resources distributed across all AZs
#   - aws_rds_cluster_parameter_group for engine tuning
#   - Monitoring, performance insights, and automated backups
# Integrate credentials via Secrets Manager or SSM where possible.
