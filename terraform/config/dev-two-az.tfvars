# Configuration DEV - sample two AZ layout (required for Aurora clusters)

project     = "soar-platform"
environment = "dev"
aws_region  = "eu-west-1"

# Two AZs (add more as needed)
availability_zones = ["eu-west-1a", "eu-west-1b"]

vpc_cidr = "10.20.0.0/16"

# Public subnets (one per AZ)
public_subnet_cidrs = {
  "a" = "10.20.0.0/20"  # eu-west-1a
  "b" = "10.20.16.0/20" # eu-west-1b
}

# Private subnets (one per AZ)
private_subnet_cidrs = {
  "a" = "10.20.64.0/20" # eu-west-1a
  "b" = "10.20.80.0/20" # eu-west-1b
}

# Database subnets (one per AZ) - Aurora requires at least 2 AZs
database_subnet_cidrs = {
  "a" = "10.20.160.0/21" # eu-west-1a
  "b" = "10.20.168.0/21" # eu-west-1b
}
