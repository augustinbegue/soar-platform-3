variable "project" {
  description = "Project or workload name used for tagging and resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (e.g., dev, staging, prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the platform will be deployed."
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to span for high availability (typically three)."
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the shared VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Map of availability zone suffix to public subnet CIDR blocks."
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Map of availability zone suffix to private (application) subnet CIDR blocks."
  type        = map(string)
}

variable "database_subnet_cidrs" {
  description = "Map of availability zone suffix to database subnet CIDR blocks."
  type        = map(string)
}
