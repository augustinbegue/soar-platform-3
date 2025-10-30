variable "name_prefix" {
  description = "Prefix applied to Aurora resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC identifier containing the Aurora subnets."
  type        = string
}

variable "database_subnet_ids" {
  description = "Subnet IDs for the Aurora DB subnet group (minimum three across AZs)."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups applied to the Aurora cluster and instances."
  type        = list(string)
  default     = []
}

variable "ecs_security_group_id" {
  description = "Security group ID of ECS tasks that should be allowed to connect to the database (used in ingress rule)."
  type        = string
  default     = ""
}
variable "engine_mode" {
  description = "Aurora cluster engine mode (provisioned, serverless, global)."
  type        = string
  default     = "provisioned"
}

variable "engine" {
  description = "Aurora engine family (aurora-mysql, aurora-postgresql)."
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version" {
  description = "Preferred engine version for the Aurora cluster."
  type        = string
  default     = "15.3"
}

variable "master_username" {
  description = "Master username for the Aurora cluster (use secrets management in production)."
  type        = string
}

variable "master_password" {
  description = "Master password for the Aurora cluster (never hard-code real secrets)."
  type        = string
  sensitive   = true
}

variable "backup_retention_period" {
  description = "Number of days to retain Aurora automatic backups."
  type        = number
  default     = 7
}
