output "cluster_arn" {
  description = "ARN of the ECS cluster hosting services."
  value       = null
}

output "capacity_provider_names" {
  description = "List of ECS capacity provider names available to services."
  value       = []
}

output "service_security_group_ids" {
  description = "Security groups associated with ECS services."
  value       = []
}
