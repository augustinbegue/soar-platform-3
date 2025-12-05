locals {
  tags = {
    Component = "monitoring"
    Name      = var.name_prefix
  }
}

# ========================================
# CloudWatch Dashboard
# ========================================

resource "aws_cloudwatch_dashboard" "ecs_monitoring" {
  dashboard_name = "${var.name_prefix}-ecs-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum", label = "Total Requests" }],
            [".", "TargetResponseTime", { stat = "Average", label = "Response Time (avg)" }],
            [".", "HTTPCode_Target_2XX_Count", { stat = "Sum", label = "2XX Responses" }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum", label = "4XX Responses" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum", label = "5XX Responses" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ALB Request Count & Response Time"
          yAxis = {
            left = {
              label = "Count / Time (ms)"
            }
          }
          dimensions = {
            LoadBalancer = var.alb_name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "ActiveConnectionCount", { stat = "Average", label = "Active Connections" }],
            [".", "NewConnectionCount", { stat = "Sum", label = "New Connections" }],
            [".", "ProcessedBytes", { stat = "Sum", label = "Processed Bytes" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ALB Connection Metrics"
          dimensions = {
            LoadBalancer = var.alb_name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average", label = "CPU Utilization" }],
            [".", "MemoryUtilization", { stat = "Average", label = "Memory Utilization" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ECS Service Resource Utilization"
          yAxis = {
            left = {
              label = "Percentage (%)"
            }
          }
          dimensions = {
            ServiceName = var.ecs_service_name
            ClusterName = var.ecs_cluster_name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "DesiredTaskCount", { stat = "Average", label = "Desired Tasks" }],
            [".", "RunningCount", { stat = "Average", label = "Running Tasks" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ECS Service Task Count"
          yAxis = {
            left = {
              label = "Count"
            }
          }
          dimensions = {
            ServiceName = var.ecs_service_name
            ClusterName = var.ecs_cluster_name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average", label = "Healthy Hosts" }],
            [".", "UnHealthyHostCount", { stat = "Average", label = "Unhealthy Hosts" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Target Group Health Status"
          yAxis = {
            left = {
              label = "Count"
            }
          }
          dimensions = {
            LoadBalancer = var.alb_name
            TargetGroup  = var.target_group_name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCountPerTarget", { stat = "Sum", label = "Requests per Target" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Request Count Per Target"
          yAxis = {
            left = {
              label = "Count"
            }
          }
          dimensions = {
            LoadBalancer = var.alb_name
            TargetGroup  = var.target_group_name
          }
        }
      },
      {
        type = "log"
        properties = {
          query  = "fields @timestamp, @message, @duration | stats count() as request_count, pct(@duration, 99) as p99_latency by bin(@timestamp, 5m)"
          region = data.aws_region.current.name
          title  = "Request Count & Latency from Logs (5-min bins)"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetTLSNegotiationErrorCount", { stat = "Sum", label = "TLS Errors" }],
            [".", "ClientTLSNegotiationErrorCount", { stat = "Sum", label = "Client TLS Errors" }],
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "ALB TLS/SSL Errors"
          yAxis = {
            left = {
              label = "Error Count"
            }
          }
          dimensions = {
            LoadBalancer = var.alb_name
          }
        }
      },
    ]
  })
}

# ========================================
# CloudWatch Alarms for Request Rate
# ========================================

# Alarm for high request rate
resource "aws_cloudwatch_metric_alarm" "alb_high_request_rate" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-high-request-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_high_request_rate_threshold
  alarm_description   = "Alert when ALB request count exceeds ${var.alb_high_request_rate_threshold} in 5 minutes"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_name
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb-high-request-rate"
  })
}

# Alarm for high response time
resource "aws_cloudwatch_metric_alarm" "alb_high_response_time" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.alb_high_response_time_threshold
  alarm_description   = "Alert when average response time exceeds ${var.alb_high_response_time_threshold} seconds"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_name
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb-high-response-time"
  })
}

# Alarm for high HTTP 5XX error rate
resource "aws_cloudwatch_metric_alarm" "alb_high_5xx_rate" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-high-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_high_5xx_threshold
  alarm_description   = "Alert when 5XX error count exceeds ${var.alb_high_5xx_threshold} in 5 minutes"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_name
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb-high-5xx-error-rate"
  })
}

# ========================================
# CloudWatch Alarms for ECS Auto-scaling
# ========================================

# Alarm for when scaling occurs due to request count
resource "aws_cloudwatch_metric_alarm" "ecs_scaling_activity" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-ecs-scaling-activity"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupDesiredCapacity"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = var.ecs_min_capacity + 1
  alarm_description   = "Alert when ECS service scales beyond minimum capacity"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.ecs_autoscaling_group_name
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-ecs-scaling-activity"
  })
}

# Alarm for unhealthy targets
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when any targets become unhealthy"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_name
    TargetGroup  = var.target_group_name
  }

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-alb-unhealthy-targets"
  })
}

# ========================================
# Data Source for AWS Region
# ========================================

data "aws_region" "current" {}
