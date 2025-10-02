variable "name_prefix" {
  description = "Prefix applied to load balancer resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC identifier where the ALB will be created."
  type        = string
}

variable "subnet_ids" {
  description = "List of public subnet IDs spanning three availability zones."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs attached to the ALB."
  type        = list(string)
}

variable "listener_ports" {
  description = "Listener definitions keyed by port with protocol and default actions."
  type = map(object({
    protocol = string
    ssl      = optional(bool, false)
  }))
  default = {
    "80" = {
      protocol = "HTTP"
      ssl      = false
    }
  }
}

variable "access_logs_bucket" {
  description = "Optional S3 bucket for ALB access logs."
  type        = string
  default     = null
}
