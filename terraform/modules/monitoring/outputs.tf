output "dashboard_url" {
  description = "URL to the CloudWatch dashboard."
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.ecs_monitoring.dashboard_name}"
}

output "dashboard_name" {
  description = "Name of the created CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.ecs_monitoring.dashboard_name
}

output "alb_high_request_rate_alarm_name" {
  description = "Name of the ALB high request rate alarm."
  value       = try(aws_cloudwatch_metric_alarm.alb_high_request_rate[0].alarm_name, "")
}

output "alb_high_response_time_alarm_name" {
  description = "Name of the ALB high response time alarm."
  value       = try(aws_cloudwatch_metric_alarm.alb_high_response_time[0].alarm_name, "")
}

output "alb_high_5xx_alarm_name" {
  description = "Name of the ALB high 5XX error rate alarm."
  value       = try(aws_cloudwatch_metric_alarm.alb_high_5xx_rate[0].alarm_name, "")
}

output "ecs_scaling_activity_alarm_name" {
  description = "Name of the ECS scaling activity alarm."
  value       = try(aws_cloudwatch_metric_alarm.ecs_scaling_activity[0].alarm_name, "")
}

output "alb_unhealthy_targets_alarm_name" {
  description = "Name of the ALB unhealthy targets alarm."
  value       = try(aws_cloudwatch_metric_alarm.alb_unhealthy_targets[0].alarm_name, "")
}
