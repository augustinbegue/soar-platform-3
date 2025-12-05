project     = "soar"
environment = "p3"
aws_region  = "eu-west-1"
availability_zones = [
  "eu-west-1a",
  "eu-west-1b",
  "eu-west-1c",
]

vpc_cidr = "10.20.0.0/16"

public_subnet_cidrs = {
  "a" = "10.20.0.0/20"
  "b" = "10.20.16.0/20"
  "c" = "10.20.32.0/20"
}

private_subnet_cidrs = {
  "a" = "10.20.64.0/20"
  "b" = "10.20.80.0/20"
  "c" = "10.20.96.0/20"
}

database_subnet_cidrs = {
  "a" = "10.20.160.0/21"
  "b" = "10.20.168.0/21"
  "c" = "10.20.176.0/21"
}
