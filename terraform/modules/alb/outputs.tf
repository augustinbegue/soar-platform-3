output "load_balancer_arn" {
  description = "ARN of the created Application Load Balancer."
  value       = aws_lb.main.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the ALB to use for ingress records."
  value       = aws_lb.main.dns_name
}

output "load_balancer_name" {
  description = "Name of the created Application Load Balancer."
  value       = aws_lb.main.name
}

output "load_balancer_arn_suffix" {
  description = "ARN suffix of the ALB (for use in CloudWatch metric dimensions)."
  value       = aws_lb.main.arn_suffix
}

output "target_group_arns" {
  description = "List of default target group ARNs fronted by the ALB."
  value       = [aws_lb_target_group.ecs.arn]
}

output "target_group_name" {
  description = "Name of the ECS target group."
  value       = aws_lb_target_group.ecs.name
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group (for use in CloudWatch metric dimensions)."
  value       = aws_lb_target_group.ecs.arn_suffix
}

output "security_group_id" {
  description = "Security group ID of the ALB."
  value       = var.security_group_ids[0]
}

