locals {
  name_prefix = "${var.project}-${var.environment}"
  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# TODO: Create the foundational networking stack here, including:
#   - VPC spanning three availability zones (var.availability_zones)
#   - Public, private, and database subnets using provided CIDR maps
#   - Internet/NAT gateways and routing tables for resilient ingress/egress
#   - Security groups for ALB, ECS services, and Aurora cluster
#   - VPC endpoints as required for private connectivity
