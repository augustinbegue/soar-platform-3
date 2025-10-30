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

output "connection_string" {
  description = "PostgreSQL connection string URI for the Aurora cluster (username/password in Secrets Manager)."
  value       = "postgresql://${aws_rds_cluster.aurora.master_username}:${var.master_password}@${aws_rds_cluster.aurora.endpoint}:5432/${aws_rds_cluster.aurora.database_name}"
  sensitive   = true
}
