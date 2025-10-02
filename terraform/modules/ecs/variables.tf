variable "name_prefix" {
  description = "Prefix applied to ECS resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC identifier used for ECS networking resources."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs across three AZs for ECS services."
  type        = list(string)
}

variable "capacity_subnet_ids" {
  description = "Subnet IDs used for ECS capacity providers (e.g., autoscaling groups)."
  type        = list(string)
}

variable "load_balancer_arn" {
  description = "ARN of the ALB distributing traffic to ECS services."
  type        = string
}

variable "target_group_arns" {
  description = "List of target group ARNs associated with the ALB listeners."
  type        = list(string)
}

variable "cluster_desired_count" {
  description = "Baseline desired count for ECS service capacity planning."
  type        = number
  default     = 2
}

variable "launch_type" {
  description = "ECS launch type to target (EC2 or FARGATE)."
  type        = string
  default     = "FARGATE"
}
