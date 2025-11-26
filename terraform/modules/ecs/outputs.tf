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
