locals {
  tags = {
    Component = "ecs"
    Name      = var.name_prefix
  }
}

# TODO: Define the ECS control plane and capacity, for example:
#   - aws_ecs_cluster with container insights enabled
#   - aws_autoscaling_group or Fargate capacity providers spanning capacity_subnet_ids
#   - aws_ecs_service definitions linking to ALB target groups
#   - AWS Service Discovery or Route53 records for service discovery
# Ensure services are distributed across all private_subnet_ids for HA.
