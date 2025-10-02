output "vpc_id" {
  description = "Identifier for the shared VPC hosting the platform."
  value       = null
}

output "public_subnet_ids" {
  description = "List of public subnet IDs used by the ALB across AZs."
  value       = []
}

output "private_subnet_ids" {
  description = "List of private subnet IDs hosting ECS workloads."
  value       = []
}

output "database_subnet_ids" {
  description = "List of dedicated subnet IDs for Aurora cluster placement."
  value       = []
}

output "alb_security_group_ids" {
  description = "Security group IDs that should be attached to ALB resources."
  value       = []
}

output "ecs_security_group_ids" {
  description = "Security group IDs applicable to ECS services and tasks."
  value       = []
}

output "aurora_security_group_ids" {
  description = "Security group IDs protecting the Aurora database cluster."
  value       = []
}
