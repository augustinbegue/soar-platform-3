variable "name_prefix" {
  description = "Prefix applied to monitoring resources."
  type        = string
}

variable "alb_name" {
  description = "Name of the Application Load Balancer for metrics."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for use in metric dimensions)."
  type        = string
  default     = ""
}

variable "target_group_name" {
  description = "Name of the target group for ALB metrics."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group (for use in metric dimensions)."
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service."
  type        = string
}

variable "ecs_autoscaling_group_name" {
  description = "Name of the ECS Auto Scaling Group (if using ASG for capacity)."
  type        = string
  default     = ""
}

variable "ecs_min_capacity" {
  description = "Minimum capacity for ECS service (for baseline in alarms)."
  type        = number
  default     = 2
}

variable "enable_alarms" {
  description = "Whether to create CloudWatch alarms for monitoring."
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger (e.g., SNS topics, Lambda)."
  type        = list(string)
  default     = []
}

variable "alb_high_request_rate_threshold" {
  description = "Threshold for high request rate alarm (requests per 5 minutes)."
  type        = number
  default     = 50000
}

variable "alb_high_response_time_threshold" {
  description = "Threshold for high response time alarm (in seconds)."
  type        = number
  default     = 1.0
}

variable "alb_high_5xx_threshold" {
  description = "Threshold for high 5XX error rate alarm (count per 5 minutes)."
  type        = number
  default     = 100
}
