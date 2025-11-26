output "load_balancer_arn" {
  description = "ARN of the created Application Load Balancer."
  value       = aws_lb.main.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the ALB to use for ingress records."
  value       = aws_lb.main.dns_name
}

output "target_group_arns" {
  description = "List of default target group ARNs fronted by the ALB."
  value       = [aws_lb_target_group.ecs.arn]
}

output "security_group_id" {
  description = "Security group ID of the ALB."
  value       = var.security_group_ids[0]
}
