locals {
  tags = {
    Component = "alb"
    Name      = var.name_prefix
  }
}

# TODO: Create the Application Load Balancer with listeners, target groups, and logging.
# Suggested resources:
#   - aws_lb
#   - aws_lb_listener (one per entry in var.listener_ports)
#   - aws_lb_target_group for ECS services
#   - Optional aws_lb_listener_certificate, aws_lb_listener_rule, aws_wafv2_web_acl_association
# Ensure load balancer is cross-zone and spans all provided subnets.
