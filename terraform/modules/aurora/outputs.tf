output "cluster_arn" {
  description = "ARN of the Aurora cluster."
  value       = aws_rds_cluster.aurora.arn
}

output "writer_endpoint" {
  description = "Writer endpoint for the Aurora cluster."
  value       = aws_rds_cluster.aurora.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint for load-balanced reads."
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "database_name" {
  description = "Database name created on the Aurora cluster."
  value       = aws_rds_cluster.aurora.database_name
}

output "connection_string" {
  description = "PostgreSQL connection string URI for the Aurora cluster (username/password in Secrets Manager)."
  value       = "postgresql://${aws_rds_cluster.aurora.master_username}:${var.master_password}@${aws_rds_cluster.aurora.endpoint}:5432/${aws_rds_cluster.aurora.database_name}"
  sensitive   = true
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the DB credentials."
  value       = aws_secretsmanager_secret.aurora_credentials.arn
  sensitive   = true
}

output "aurora_security_group_ids" {
  description = "List of VPC security group IDs associated with the Aurora cluster."
  value       = aws_rds_cluster.aurora.vpc_security_group_ids
}

output "writer_instance_id" {
  description = "Identifier of the Aurora writer instance."
  value       = aws_rds_cluster_instance.writer.id
}

output "reader_instance_ids" {
  description = "List of reader instance identifiers across all AZs."
  value = concat(
    aws_rds_cluster_instance.reader_a[*].id,
    aws_rds_cluster_instance.reader_b[*].id,
    aws_rds_cluster_instance.reader_c[*].id
  )
}

output "reader_instance_endpoints" {
  description = "Individual endpoints for each reader instance (for direct access if needed)."
  value = {
    reader_a = length(aws_rds_cluster_instance.reader_a) > 0 ? aws_rds_cluster_instance.reader_a[0].endpoint : null
    reader_b = length(aws_rds_cluster_instance.reader_b) > 0 ? aws_rds_cluster_instance.reader_b[0].endpoint : null
    reader_c = length(aws_rds_cluster_instance.reader_c) > 0 ? aws_rds_cluster_instance.reader_c[0].endpoint : null
  }
}

output "cluster_member_count" {
  description = "Total number of cluster members (writer + readers)."
  value       = 1 + length(aws_rds_cluster_instance.reader_a) + length(aws_rds_cluster_instance.reader_b) + length(aws_rds_cluster_instance.reader_c)
}
