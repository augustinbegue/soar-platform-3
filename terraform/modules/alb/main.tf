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

# ========================================
# Application Load Balancer
# ========================================

resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# ========================================
# Target Group for ECS Service
# ========================================

resource "aws_lb_target_group" "ecs" {
  name        = "${var.name_prefix}-ecs-tg"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    port                = "3001"
  }

  deregistration_delay = 30

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-ecs-tg"
  })
}

# ========================================
# HTTP Listener
# ========================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-http-listener"
  })
}
