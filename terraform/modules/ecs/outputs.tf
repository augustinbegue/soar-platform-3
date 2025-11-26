output "cluster_arn" {
  description = "ARN of the ECS cluster hosting services."
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "capacity_provider_names" {
  description = "List of ECS capacity provider names available to services."
  value       = ["FARGATE", "FARGATE_SPOT"]
}

output "service_security_group_ids" {
  description = "Security groups associated with ECS services."
  value       = [aws_security_group.ecs_tasks.id]
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks."
  value       = aws_security_group.ecs_tasks.id
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the IAM role for ECS task execution."
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the IAM role for ECS tasks (application)."
  value       = aws_iam_role.ecs_task_role.arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition."
  value       = aws_ecs_task_definition.app.arn
}

output "task_definition_family" {
  description = "Family of the ECS task definition."
  value       = aws_ecs_task_definition.app.family
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for ECS tasks."
  value       = aws_cloudwatch_log_group.ecs_tasks.name
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.app.name
}

output "service_id" {
  description = "ID of the ECS service."
  value       = aws_ecs_service.app.id
}

output "autoscaling_enabled" {
  description = "Whether auto-scaling is enabled for the ECS service."
  value       = var.autoscaling_enabled
}

output "autoscaling_target_resource_id" {
  description = "Resource ID of the auto-scaling target."
  value       = var.autoscaling_enabled ? aws_appautoscaling_target.ecs_service[0].resource_id : null
}

output "autoscaling_min_capacity" {
  description = "Minimum number of tasks for auto-scaling."
  value       = var.autoscaling_min_capacity
}

output "autoscaling_max_capacity" {
  description = "Maximum number of tasks for auto-scaling."
  value       = var.autoscaling_max_capacity
}

output "autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for auto-scaling."
  value       = var.autoscaling_cpu_target
}

output "cpu_high_alarm_name" {
  description = "Name of the CloudWatch alarm for high CPU utilization."
  value       = var.autoscaling_enabled ? aws_cloudwatch_metric_alarm.ecs_cpu_high[0].alarm_name : null
}

output "cpu_low_alarm_name" {
  description = "Name of the CloudWatch alarm for low CPU utilization."
  value       = var.autoscaling_enabled ? aws_cloudwatch_metric_alarm.ecs_cpu_low[0].alarm_name : null
}

