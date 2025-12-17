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
  value       = local.writer_az != null ? aws_rds_cluster_instance.instances[local.writer_az].id : null
}

output "reader_instance_ids" {
  description = "List of reader instance identifiers across all AZs."
  value = [
    for az in local.reader_azs : aws_rds_cluster_instance.instances[az].id
  ]
}

output "reader_instance_endpoints" {
  description = "Individual endpoints for each reader instance (for direct access if needed)."
  value = {
    for az in local.reader_azs : az => aws_rds_cluster_instance.instances[az].endpoint
  }
}

output "cluster_member_count" {
  description = "Total number of cluster members (writer + readers)."
  value       = length(var.availability_zones)
}

output "instance_ids" {
  description = "Map of all instance IDs by availability zone."
  value = {
    for az, instance in aws_rds_cluster_instance.instances : az => instance.id
  }
}

output "instance_endpoints" {
  description = "Map of all instance endpoints by availability zone."
  value = {
    for az, instance in aws_rds_cluster_instance.instances : az => instance.endpoint
  }
}

output "serverless_scaling_configuration" {
  description = "Serverless v2 auto-scaling configuration (min/max ACU)."
  value = {
    min_capacity = var.serverless_min_capacity
    max_capacity = var.serverless_max_capacity
  }
}

output "cloudwatch_monitoring_commands" {
  description = "AWS CLI commands to monitor Aurora Serverless v2 scaling metrics."
  value = {
    serverless_capacity  = "aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name ServerlessDatabaseCapacity --dimensions Name=DBClusterIdentifier,Value=${aws_rds_cluster.aurora.cluster_identifier} --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Average,Maximum --region ${aws_rds_cluster.aurora.arn != "" ? split(":", aws_rds_cluster.aurora.arn)[3] : "eu-west-1"}"
    cpu_utilization      = "aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization --dimensions Name=DBClusterIdentifier,Value=${aws_rds_cluster.aurora.cluster_identifier} --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Average,Maximum --region ${aws_rds_cluster.aurora.arn != "" ? split(":", aws_rds_cluster.aurora.arn)[3] : "eu-west-1"}"
    database_connections = "aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name DatabaseConnections --dimensions Name=DBClusterIdentifier,Value=${aws_rds_cluster.aurora.cluster_identifier} --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Average,Maximum --region ${aws_rds_cluster.aurora.arn != "" ? split(":", aws_rds_cluster.aurora.arn)[3] : "eu-west-1"}"
  }
}
