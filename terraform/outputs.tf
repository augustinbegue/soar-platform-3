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

# output "aurora_cluster_arn" {
#   description = "ARN of the Aurora database cluster."
#   value       = module.aurora.cluster_arn
# }