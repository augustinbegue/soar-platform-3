# Configuration Single AZ - DEV/TEST SEULEMENT

project     = "soar-platform"
environment = "dev"
aws_region  = "eu-west-1"

# Single AZ pour économiser
availability_zones = ["eu-west-1a"]

vpc_cidr = "10.20.0.0/16"

# Public subnet (1 seul AZ)
public_subnet_cidrs = {
  "a" = "10.20.0.0/20"  # 10.20.0.0 - 10.20.15.255 (4091 IPs)
}

# Private subnet (1 seul AZ)
private_subnet_cidrs = {
  "a" = "10.20.64.0/20"  # 10.20.64.0 - 10.20.79.255 (4091 IPs)
}

# Database subnet (1 seul AZ)
database_subnet_cidrs = {
  "a" = "10.20.160.0/21"  # 10.20.160.0 - 10.20.167.255 (2043 IPs)
}
