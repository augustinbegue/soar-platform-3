output "load_balancer_arn" {
  description = "ARN of the created Application Load Balancer."
  value       = null
}

output "load_balancer_dns_name" {
  description = "DNS name of the ALB to use for ingress records."
  value       = null
}

output "target_group_arns" {
  description = "List of default target group ARNs fronted by the ALB."
  value       = []
}
