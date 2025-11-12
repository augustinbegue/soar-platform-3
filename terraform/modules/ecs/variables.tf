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

variable "container_image" {
  description = "Container image to run for the application (allows swapping to a CRUD app)."
  type        = string
  default     = "nginx:latest"
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds DB credentials (optional)."
  type        = string
  default     = ""
}

variable "db_writer_endpoint" {
  description = "Writer endpoint for the database cluster (hostname) used by the app."
  type        = string
  default     = ""
}

variable "aurora_security_group_ids" {
  description = "List of Aurora VPC security group IDs so ECS can create an ingress rule allowing DB traffic from tasks." 
  type        = list(string)
  default     = []
}

variable "db_name" {
  description = "Name of the database to connect to (injected as DB_NAME env var)."
  type        = string
  default     = ""
}

variable "db_reader_endpoint" {
  description = "Load-balanced reader endpoint for Aurora cluster (fallback)."
  type        = string
  default     = ""
}

variable "db_reader_endpoints_per_az" {
  description = "Map of reader endpoints per AZ (reader_a, reader_b, reader_c)."
  type = map(string)
  default = {
    reader_a = ""
    reader_b = ""
    reader_c = ""
  }
}

variable "availability_zones" {
  description = "List of availability zones matching the order of private_subnet_ids."
  type        = list(string)
  default     = []
}
