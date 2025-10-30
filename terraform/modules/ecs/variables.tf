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

variable "target_group_arns" {
  description = "List of target group ARNs associated with the ALB listeners."
  type        = list(string)
  default     = []
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB to allow traffic from ALB to ECS."
  type        = string
  default     = ""
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
