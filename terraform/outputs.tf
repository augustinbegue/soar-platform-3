output "vpc_id" {
  description = "Identifier of the shared platform VPC."
  value       = module.core.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the platform Application Load Balancer."
  value       = module.alb.load_balancer_dns_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster handling compute workloads."
  value       = module.ecs.cluster_arn
}

output "aurora_cluster_arn" {
  description = "ARN of the Aurora database cluster."
  value       = module.aurora.cluster_arn
}
