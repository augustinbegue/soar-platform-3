output "vpc_id" {
  description = "Identifier of the shared platform VPC."
  value       = module.core.vpc_id
}

# output "alb_dns_name" {
#   description = "DNS name of the platform Application Load Balancer."
#   value       = module.alb.load_balancer_dns_name
# }

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster handling compute workloads."
  value       = module.ecs.cluster_arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = module.ecs.service_name
}

output "ecs_logs_command" {
  description = "Command to view ECS logs in real-time."
  value       = "aws logs tail ${module.ecs.cloudwatch_log_group_name} --follow --region ${var.aws_region}"
}

output "frontend_url" {
  description = "URL to access the frontend hosted on S3"
  value       = module.s3_frontend.website_url
}

output "frontend_bucket" {
  description = "S3 bucket name hosting the frontend"
  value       = module.s3_frontend.bucket_name
}

# output "aurora_cluster_arn" {
#   description = "ARN of the Aurora database cluster."
#   value       = module.aurora.cluster_arn
# }
# ========================================
# Aurora Database Outputs
# ========================================

output "aurora_cluster_arn" {
  description = "ARN of the Aurora database cluster"
  value       = module.aurora.cluster_arn
}

output "aurora_writer_endpoint" {
  description = "Writer endpoint for Aurora cluster (use for writes)"
  value       = module.aurora.writer_endpoint
}

output "aurora_reader_endpoint" {
  description = "Reader endpoint for Aurora cluster (load-balanced reads across all replicas)"
  value       = module.aurora.reader_endpoint
}

output "aurora_database_name" {
  description = "Database name in Aurora cluster"
  value       = module.aurora.database_name
}

output "aurora_writer_instance_id" {
  description = "Writer instance identifier"
  value       = module.aurora.writer_instance_id
}

output "aurora_reader_instance_ids" {
  description = "List of reader instance identifiers"
  value       = module.aurora.reader_instance_ids
}

output "aurora_cluster_member_count" {
  description = "Total number of cluster members (1 writer + N readers)"
  value       = module.aurora.cluster_member_count
}

output "aurora_reader_instance_endpoints" {
  description = "Individual reader instance endpoints per AZ (reader_a, reader_b, reader_c)"
  value       = module.aurora.reader_instance_endpoints
}
