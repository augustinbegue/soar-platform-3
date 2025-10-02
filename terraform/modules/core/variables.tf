variable "project" {
  description = "Project or workload name used for tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the deployment (informational only)."
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to span."
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the shared VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Map of AZ suffix -> public subnet CIDR blocks."
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Map of AZ suffix -> private subnet CIDR blocks."
  type        = map(string)
}

variable "database_subnet_cidrs" {
  description = "Map of AZ suffix -> database subnet CIDR blocks."
  type        = map(string)
}
