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
  # Leave empty to use the provider's default (recommended). Set to a specific version
  # only if you need a particular engine release supported in your region/account.
  default     = ""
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

variable "skip_final_snapshot" {
  description = "If true, skip creating a final snapshot when the cluster is deleted. Set to false to keep a final snapshot (useful for prod)."
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Optional final snapshot identifier used when skip_final_snapshot is false. If empty, a generated identifier will be used." 
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "List of availability zones for read replica distribution"
  type        = list(string)
  default     = []
}
